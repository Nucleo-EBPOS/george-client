//! GEORGE: login automático do sistema ("Entrar automaticamente ao ligar").
//!
//! Recurso do George nos três sistemas, ligado na tela "Configurar este computador":
//! - **Windows**: senha como segredo LSA `DefaultPassword` (igual ao Sysinternals Autologon),
//!   nunca em texto puro no registro. Quem grava é o serviço (SYSTEM), via IPC, e só depois de
//!   validar a credencial com `LogonUserW`.
//! - **macOS**: login automático nativo (`/etc/kcpassword` + `autoLoginUser`). Aplicado por um
//!   processo do George elevado pelo diálogo de administrador do próprio macOS. Bloqueado pelo
//!   sistema quando o FileVault está ativo — avisamos.
//! - **Linux**: configura o gerenciador de login (GDM, LightDM ou SDDM). Não precisa de senha.
//!   Aplicado por um processo do George elevado com `pkexec`.
//!
//! A senha nunca vai para linha de comando nem para o Config do George: no macOS/Linux ela
//! passa por um arquivo temporário 0600 que o processo elevado lê e apaga.
#[allow(unused_imports)]
use hbb_common::{bail, log, ResultType};
use serde::{Deserialize, Serialize};

/// Nome da mensagem `Data::Config` no IPC (Windows).
pub const IPC_KEY: &str = "george-autologon";
/// Argumento do processo elevado (macOS/Linux): `George --george-autologon-apply <arquivo>`.
pub const APPLY_ARG: &str = "--george-autologon-apply";

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct Req {
    #[serde(default)]
    pub user: String,
    #[serde(default)]
    pub domain: String,
    #[serde(default)]
    pub password: String,
}

/// Informações para a UI (JSON): suporte, se precisa de senha, usuário/domínio atuais e estado.
pub fn info() -> String {
    let (supported, needs_password, note) = support();
    let user = std::env::var(if cfg!(windows) { "USERNAME" } else { "USER" }).unwrap_or_default();
    let domain = if cfg!(windows) {
        std::env::var("USERDOMAIN").unwrap_or_default()
    } else {
        String::new()
    };
    serde_json::json!({
        "supported": supported,
        "needs_password": needs_password,
        "user": user,
        "domain": domain,
        "status": status(),
        "note": note,
    })
    .to_string()
}

/// "on:<usuário>", "off" ou "unsupported".
pub fn status() -> String {
    imp::status()
}

fn support() -> (bool, bool, String) {
    imp::support()
}

/// Lado da UI: liga (usuário preenchido) ou desliga (usuário vazio). Devolve "Y" ou "N:<erro>".
pub fn request(user: String, domain: String, password: String) -> String {
    let r = Req { user, domain, password };
    match imp::request(r) {
        Ok(s) => s,
        Err(e) => format!("N:{}", e),
    }
}

/// Lado privilegiado (serviço Windows / processo elevado). Devolve "Y" ou "N:<erro>".
pub fn apply(r: &Req) -> String {
    match imp::apply(r) {
        Ok(()) => {
            log::info!(
                "george autologon: {}",
                if r.user.trim().is_empty() { "desligado".to_owned() } else { format!("ligado para {}", r.user.trim()) }
            );
            "Y".to_owned()
        }
        Err(e) => {
            log::error!("george autologon: {}", e);
            format!("N:{}", e)
        }
    }
}

/// Windows: mensagem do IPC (JSON).
pub fn apply_from_ipc(value: &str) -> String {
    match serde_json::from_str::<Req>(value) {
        Ok(r) => apply(&r),
        Err(e) => format!("N:{}", e),
    }
}

/// macOS/Linux: entrada do processo elevado. Lê o pedido, APAGA o arquivo, aplica e imprime
/// o resultado (lido pela UI). Devolve o exit code.
pub fn apply_file_cli(path: &str) -> i32 {
    let data = std::fs::read_to_string(path);
    let _ = std::fs::remove_file(path);
    let out = match data.ok().and_then(|s| serde_json::from_str::<Req>(&s).ok()) {
        Some(r) => apply(&r),
        None => "N:pedido inválido".to_owned(),
    };
    println!("{}", out);
    if out == "Y" {
        0
    } else {
        1
    }
}

// ---------------------------------------------------------------- comum macOS/Linux

/// Grava o pedido num arquivo 0600 e roda o George elevado para aplicá-lo.
#[cfg(any(target_os = "macos", target_os = "linux"))]
fn request_elevated(r: Req) -> ResultType<String> {
    use std::io::Write;
    use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};
    let exe = std::env::current_exe()?;
    let path = std::env::temp_dir().join(format!("george-autologon-{}.json", std::process::id()));
    {
        let mut f = std::fs::OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .mode(0o600)
            .open(&path)?;
        f.write_all(serde_json::to_string(&r)?.as_bytes())?;
    }
    std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600)).ok();
    let res = imp::run_elevated(&exe, &path);
    let _ = std::fs::remove_file(&path);
    let out = res?;
    let last = out.lines().rev().find(|l| !l.trim().is_empty()).unwrap_or("").trim().to_owned();
    if last == "Y" || last.starts_with("N:") {
        Ok(last)
    } else if last.is_empty() {
        Ok("N:cancelado".to_owned())
    } else {
        Ok(format!("N:{}", last))
    }
}

// ---------------------------------------------------------------- Windows

#[cfg(windows)]
mod imp {
    use super::Req;
    use hbb_common::{bail, tokio, ResultType};
    use std::ffi::c_void;
    use winreg::{enums::*, RegKey};

    const WINLOGON: &str = r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon";
    const POLICY_CREATE_SECRET: u32 = 0x0000_0020;
    const LOGON32_LOGON_INTERACTIVE: u32 = 2;
    const LOGON32_PROVIDER_DEFAULT: u32 = 0;

    #[repr(C)]
    struct LsaUnicodeString {
        length: u16,
        maximum_length: u16,
        buffer: *mut u16,
    }

    #[repr(C)]
    struct LsaObjectAttributes {
        length: u32,
        root_directory: *mut c_void,
        object_name: *mut LsaUnicodeString,
        attributes: u32,
        security_descriptor: *mut c_void,
        security_quality_of_service: *mut c_void,
    }

    #[link(name = "advapi32")]
    extern "system" {
        fn LsaOpenPolicy(
            system_name: *mut LsaUnicodeString,
            object_attributes: *mut LsaObjectAttributes,
            desired_access: u32,
            policy_handle: *mut *mut c_void,
        ) -> i32;
        fn LsaStorePrivateData(
            policy_handle: *mut c_void,
            key_name: *mut LsaUnicodeString,
            private_data: *mut LsaUnicodeString,
        ) -> i32;
        fn LsaClose(object_handle: *mut c_void) -> i32;
        fn LogonUserW(
            user: *const u16,
            domain: *const u16,
            password: *const u16,
            logon_type: u32,
            provider: u32,
            token: *mut *mut c_void,
        ) -> i32;
    }

    #[link(name = "kernel32")]
    extern "system" {
        fn CloseHandle(h: *mut c_void) -> i32;
        fn GetLastError() -> u32;
    }

    fn wide(s: &str) -> Vec<u16> {
        s.encode_utf16().chain(std::iter::once(0)).collect()
    }

    fn lsa_string(v: &mut Vec<u16>) -> LsaUnicodeString {
        let bytes = (v.len() * 2) as u16;
        LsaUnicodeString { length: bytes, maximum_length: bytes, buffer: v.as_mut_ptr() }
    }

    /// Confere usuário/senha no próprio Windows antes de salvar (senha errada = PC preso no login).
    fn validate(user: &str, domain: &str, password: &str) -> ResultType<()> {
        let u = wide(user);
        let d = wide(if domain.is_empty() { "." } else { domain });
        let mut p = wide(password);
        let mut token: *mut c_void = std::ptr::null_mut();
        let ok = unsafe {
            LogonUserW(
                u.as_ptr(),
                d.as_ptr(),
                p.as_ptr(),
                LOGON32_LOGON_INTERACTIVE,
                LOGON32_PROVIDER_DEFAULT,
                &mut token,
            )
        };
        for c in p.iter_mut() {
            *c = 0;
        }
        if ok == 0 {
            let e = unsafe { GetLastError() };
            if e == 1326 {
                bail!("usuário ou senha incorretos");
            }
            bail!("o Windows recusou a credencial (erro {})", e);
        }
        unsafe {
            CloseHandle(token);
        }
        Ok(())
    }

    fn lsa_store_default_password(password: Option<&str>) -> ResultType<()> {
        let mut key: Vec<u16> = "DefaultPassword".encode_utf16().collect();
        let mut data: Vec<u16> = password.unwrap_or_default().encode_utf16().collect();
        let mut attrs = LsaObjectAttributes {
            length: std::mem::size_of::<LsaObjectAttributes>() as u32,
            root_directory: std::ptr::null_mut(),
            object_name: std::ptr::null_mut(),
            attributes: 0,
            security_descriptor: std::ptr::null_mut(),
            security_quality_of_service: std::ptr::null_mut(),
        };
        let mut handle: *mut c_void = std::ptr::null_mut();
        unsafe {
            let st = LsaOpenPolicy(std::ptr::null_mut(), &mut attrs, POLICY_CREATE_SECRET, &mut handle);
            if st != 0 {
                bail!("LsaOpenPolicy 0x{:08x}", st as u32);
            }
            let mut k = lsa_string(&mut key);
            let st = if password.is_some() {
                let mut d = lsa_string(&mut data);
                LsaStorePrivateData(handle, &mut k, &mut d)
            } else {
                LsaStorePrivateData(handle, &mut k, std::ptr::null_mut())
            };
            LsaClose(handle);
            // 0xC0000034 = OBJECT_NAME_NOT_FOUND ao apagar um segredo que não existe.
            if st != 0 && !(password.is_none() && st as u32 == 0xC000_0034) {
                bail!("LsaStorePrivateData 0x{:08x}", st as u32);
            }
        }
        for c in data.iter_mut() {
            *c = 0;
        }
        Ok(())
    }

    pub fn support() -> (bool, bool, String) {
        (true, true, String::new())
    }

    pub fn apply(r: &Req) -> ResultType<()> {
        let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
        let key = hklm.open_subkey_with_flags(WINLOGON, KEY_READ | KEY_WRITE)?;
        let _ = key.delete_value("DefaultPassword");
        let user = r.user.trim();
        if user.is_empty() {
            key.set_value("AutoAdminLogon", &"0")?;
            lsa_store_default_password(None)?;
            return Ok(());
        }
        if r.password.is_empty() {
            bail!("informe a senha do Windows");
        }
        validate(user, r.domain.trim(), &r.password)?;
        lsa_store_default_password(Some(&r.password))?;
        key.set_value("DefaultUserName", &user)?;
        key.set_value("DefaultDomainName", &r.domain.trim())?;
        key.set_value("AutoAdminLogon", &"1")?;
        let _ = key.delete_value("AutoLogonCount");
        Ok(())
    }

    pub fn status() -> String {
        let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
        let Ok(key) = hklm.open_subkey_with_flags(WINLOGON, KEY_READ) else {
            return "off".to_owned();
        };
        let on: String = key.get_value("AutoAdminLogon").unwrap_or_default();
        if on.trim() != "1" {
            return "off".to_owned();
        }
        let user: String = key.get_value("DefaultUserName").unwrap_or_default();
        let domain: String = key.get_value("DefaultDomainName").unwrap_or_default();
        if domain.is_empty() {
            format!("on:{}", user)
        } else {
            format!("on:{}\\{}", domain, user)
        }
    }

    pub fn request(r: Req) -> ResultType<String> {
        request_async(serde_json::to_string(&r)?)
    }

    #[tokio::main(flavor = "current_thread")]
    async fn request_async(value: String) -> ResultType<String> {
        use crate::ipc::Data;
        let mut c = crate::ipc::connect(1_000, "").await?;
        c.send(&Data::Config((super::IPC_KEY.to_owned(), Some(value)))).await?;
        if let Some(Data::Config((name, Some(v)))) = c.next_timeout(8_000).await? {
            if name == super::IPC_KEY {
                return Ok(v);
            }
        }
        Ok("N:o serviço do George não respondeu".to_owned())
    }
}

// ---------------------------------------------------------------- macOS

#[cfg(target_os = "macos")]
mod imp {
    use super::Req;
    use hbb_common::{bail, ResultType};
    use std::path::Path;
    use std::process::Command;

    const LOGINWINDOW: &str = "/Library/Preferences/com.apple.loginwindow";
    const KCPASSWORD: &str = "/etc/kcpassword";

    fn filevault_on() -> bool {
        Command::new("/usr/bin/fdesetup")
            .arg("isactive")
            .output()
            .map(|o| String::from_utf8_lossy(&o.stdout).trim() == "true")
            .unwrap_or(false)
    }

    /// Formato do /etc/kcpassword (XOR com a chave fixa da Apple, 1 byte nulo de terminação e
    /// preenchimento até múltiplo de 12).
    fn kcpassword(password: &str) -> Vec<u8> {
        const KEY: [u8; 11] = [125, 137, 82, 35, 210, 188, 221, 234, 163, 185, 31];
        let mut b = password.as_bytes().to_vec();
        b.push(0);
        while b.len() % 12 != 0 {
            b.push(0);
        }
        for (i, c) in b.iter_mut().enumerate() {
            *c ^= KEY[i % KEY.len()];
        }
        b
    }

    pub fn support() -> (bool, bool, String) {
        if filevault_on() {
            (false, true, "filevault".to_owned())
        } else {
            (true, true, String::new())
        }
    }

    pub fn apply(r: &Req) -> ResultType<()> {
        use std::os::unix::fs::PermissionsExt;
        let user = r.user.trim();
        if user.is_empty() {
            let _ = Command::new("/usr/bin/defaults").args(["delete", LOGINWINDOW, "autoLoginUser"]).output();
            let _ = std::fs::remove_file(KCPASSWORD);
            return Ok(());
        }
        if filevault_on() {
            bail!("o FileVault está ativo — o macOS não permite login automático");
        }
        if r.password.is_empty() {
            bail!("informe a senha do Mac");
        }
        std::fs::write(KCPASSWORD, kcpassword(&r.password))?;
        std::fs::set_permissions(KCPASSWORD, std::fs::Permissions::from_mode(0o600))?;
        let _ = Command::new("/usr/sbin/chown").args(["root:wheel", KCPASSWORD]).output();
        let o = Command::new("/usr/bin/defaults")
            .args(["write", LOGINWINDOW, "autoLoginUser", "-string", user])
            .output()?;
        if !o.status.success() {
            bail!("defaults: {}", String::from_utf8_lossy(&o.stderr).trim());
        }
        Ok(())
    }

    pub fn status() -> String {
        let o = Command::new("/usr/bin/defaults").args(["read", LOGINWINDOW, "autoLoginUser"]).output();
        match o {
            Ok(o) if o.status.success() => {
                let u = String::from_utf8_lossy(&o.stdout).trim().to_owned();
                if u.is_empty() || !Path::new(KCPASSWORD).exists() {
                    "off".to_owned()
                } else {
                    format!("on:{}", u)
                }
            }
            _ => "off".to_owned(),
        }
    }

    pub fn request(r: Req) -> ResultType<String> {
        super::request_elevated(r)
    }

    /// Diálogo de administrador nativo do macOS (osascript … with administrator privileges).
    pub fn run_elevated(exe: &Path, file: &Path) -> ResultType<String> {
        fn q(s: &str) -> String {
            format!("'{}'", s.replace('\'', "'\\''"))
        }
        let sh = format!("{} {} {}", q(&exe.to_string_lossy()), super::APPLY_ARG, q(&file.to_string_lossy()));
        let script = format!(
            "do shell script \"{}\" with prompt \"O George precisa de permissão para configurar o login automático.\" with administrator privileges",
            sh.replace('\\', "\\\\").replace('"', "\\\"")
        );
        let o = Command::new("/usr/bin/osascript").args(["-e", &script]).output()?;
        if !o.status.success() {
            let e = String::from_utf8_lossy(&o.stderr);
            if e.contains("-128") {
                return Ok("N:cancelado".to_owned());
            }
            // o processo elevado imprime N:<erro> no stdout mesmo com exit 1
            let out = String::from_utf8_lossy(&o.stdout).to_string();
            if !out.trim().is_empty() {
                return Ok(out);
            }
            bail!("{}", e.trim());
        }
        Ok(String::from_utf8_lossy(&o.stdout).to_string())
    }
}

// ---------------------------------------------------------------- Linux

#[cfg(target_os = "linux")]
mod imp {
    use super::Req;
    use hbb_common::{bail, ResultType};
    use std::path::{Path, PathBuf};
    use std::process::Command;

    const LIGHTDM_DROPIN: &str = "/etc/lightdm/lightdm.conf.d/90-george-autologin.conf";
    const SDDM_DROPIN: &str = "/etc/sddm.conf.d/90-george-autologin.conf";

    #[derive(PartialEq)]
    enum Dm {
        Gdm(PathBuf),
        LightDm,
        Sddm,
        Unknown,
    }

    fn gdm_conf() -> Option<PathBuf> {
        ["/etc/gdm3/custom.conf", "/etc/gdm3/daemon.conf", "/etc/gdm/custom.conf"]
            .iter()
            .map(PathBuf::from)
            .find(|p| p.exists())
    }

    fn detect() -> Dm {
        let target = std::fs::read_link("/etc/systemd/system/display-manager.service")
            .map(|p| p.to_string_lossy().to_lowercase())
            .unwrap_or_default();
        let has = |n: &str| target.contains(n);
        if has("gdm") {
            if let Some(p) = gdm_conf() {
                return Dm::Gdm(p);
            }
        }
        if has("lightdm") {
            return Dm::LightDm;
        }
        if has("sddm") {
            return Dm::Sddm;
        }
        if let Some(p) = gdm_conf() {
            return Dm::Gdm(p);
        }
        if Path::new("/etc/lightdm").exists() {
            return Dm::LightDm;
        }
        if Path::new("/etc/sddm.conf").exists() || Path::new("/etc/sddm.conf.d").exists() {
            return Dm::Sddm;
        }
        Dm::Unknown
    }

    /// Define/remove chaves numa seção de um arquivo .ini preservando o resto.
    fn ini_set(text: &str, section: &str, kv: &[(&str, Option<&str>)]) -> String {
        let header = format!("[{}]", section);
        let keys: Vec<&str> = kv.iter().map(|(k, _)| *k).collect();
        let mut out: Vec<String> = Vec::new();
        let mut in_sec = false;
        let mut found = false;
        let mut written = false;
        let write_kv = |out: &mut Vec<String>| {
            for (k, v) in kv {
                if let Some(v) = v {
                    out.push(format!("{}={}", k, v));
                }
            }
        };
        for line in text.lines() {
            let t = line.trim();
            if t.starts_with('[') {
                if in_sec && !written {
                    write_kv(&mut out);
                    written = true;
                }
                in_sec = t.eq_ignore_ascii_case(&header);
                if in_sec {
                    found = true;
                }
                out.push(line.to_owned());
                continue;
            }
            if in_sec {
                let k = t.trim_start_matches('#').split('=').next().unwrap_or("").trim();
                if keys.contains(&k) {
                    continue;
                }
            }
            out.push(line.to_owned());
        }
        if in_sec && !written {
            write_kv(&mut out);
        }
        if !found {
            out.push(String::new());
            out.push(header);
            write_kv(&mut out);
        }
        let mut s = out.join("\n");
        s.push('\n');
        s
    }

    fn ini_get(text: &str, section: &str, key: &str) -> Option<String> {
        let header = format!("[{}]", section);
        let mut in_sec = false;
        for line in text.lines() {
            let t = line.trim();
            if t.starts_with('[') {
                in_sec = t.eq_ignore_ascii_case(&header);
                continue;
            }
            if in_sec && !t.starts_with('#') {
                if let Some((k, v)) = t.split_once('=') {
                    if k.trim() == key {
                        return Some(v.trim().to_owned());
                    }
                }
            }
        }
        None
    }

    fn sddm_session() -> String {
        for dir in ["/usr/share/xsessions", "/usr/share/wayland-sessions"] {
            if let Ok(rd) = std::fs::read_dir(dir) {
                let mut names: Vec<String> = rd
                    .filter_map(|e| e.ok())
                    .map(|e| e.file_name().to_string_lossy().to_string())
                    .filter(|n| n.ends_with(".desktop"))
                    .collect();
                names.sort();
                if let Some(n) = names.iter().find(|n| n.contains("plasma")).or(names.first()) {
                    return n.clone();
                }
            }
        }
        String::new()
    }

    pub fn support() -> (bool, bool, String) {
        if detect() == Dm::Unknown {
            (false, false, "display_manager".to_owned())
        } else {
            (true, false, String::new())
        }
    }

    pub fn apply(r: &Req) -> ResultType<()> {
        let user = r.user.trim();
        let on = !user.is_empty();
        match detect() {
            Dm::Gdm(p) => {
                let text = std::fs::read_to_string(&p).unwrap_or_default();
                let new = if on {
                    ini_set(&text, "daemon", &[("AutomaticLoginEnable", Some("true")), ("AutomaticLogin", Some(user))])
                } else {
                    ini_set(&text, "daemon", &[("AutomaticLoginEnable", Some("false")), ("AutomaticLogin", None)])
                };
                std::fs::write(&p, new)?;
            }
            Dm::LightDm => {
                if on {
                    std::fs::create_dir_all("/etc/lightdm/lightdm.conf.d")?;
                    std::fs::write(
                        LIGHTDM_DROPIN,
                        format!("[Seat:*]\nautologin-user={}\nautologin-user-timeout=0\n", user),
                    )?;
                    // algumas distros exigem o grupo autologin
                    let _ = Command::new("groupadd").args(["-f", "-r", "autologin"]).output();
                    let _ = Command::new("gpasswd").args(["-a", user, "autologin"]).output();
                } else {
                    let _ = std::fs::remove_file(LIGHTDM_DROPIN);
                }
            }
            Dm::Sddm => {
                if on {
                    std::fs::create_dir_all("/etc/sddm.conf.d")?;
                    std::fs::write(
                        SDDM_DROPIN,
                        format!("[Autologin]\nUser={}\nSession={}\nRelogin=false\n", user, sddm_session()),
                    )?;
                } else {
                    let _ = std::fs::remove_file(SDDM_DROPIN);
                }
            }
            Dm::Unknown => bail!("gerenciador de login não suportado (use GDM, LightDM ou SDDM)"),
        }
        Ok(())
    }

    pub fn status() -> String {
        match detect() {
            Dm::Gdm(p) => {
                let t = std::fs::read_to_string(p).unwrap_or_default();
                let en = ini_get(&t, "daemon", "AutomaticLoginEnable").unwrap_or_default();
                let u = ini_get(&t, "daemon", "AutomaticLogin").unwrap_or_default();
                if en.eq_ignore_ascii_case("true") && !u.is_empty() {
                    format!("on:{}", u)
                } else {
                    "off".to_owned()
                }
            }
            Dm::LightDm => std::fs::read_to_string(LIGHTDM_DROPIN)
                .ok()
                .and_then(|t| ini_get(&t, "Seat:*", "autologin-user"))
                .filter(|u| !u.is_empty())
                .map(|u| format!("on:{}", u))
                .unwrap_or_else(|| "off".to_owned()),
            Dm::Sddm => std::fs::read_to_string(SDDM_DROPIN)
                .ok()
                .and_then(|t| ini_get(&t, "Autologin", "User"))
                .filter(|u| !u.is_empty())
                .map(|u| format!("on:{}", u))
                .unwrap_or_else(|| "off".to_owned()),
            Dm::Unknown => "unsupported".to_owned(),
        }
    }

    pub fn request(r: Req) -> ResultType<String> {
        super::request_elevated(r)
    }

    /// pkexec (diálogo de senha do polkit). Já como root (ex.: serviço), aplica direto.
    pub fn run_elevated(exe: &Path, file: &Path) -> ResultType<String> {
        let mut cmd = if crate::platform::is_root() {
            let mut c = Command::new(exe);
            c.arg(super::APPLY_ARG).arg(file);
            c
        } else {
            let mut c = Command::new("pkexec");
            c.arg(exe).arg(super::APPLY_ARG).arg(file);
            c
        };
        let o = cmd.output()?;
        let out = String::from_utf8_lossy(&o.stdout).to_string();
        if !o.status.success() && out.trim().is_empty() {
            let code = o.status.code().unwrap_or(-1);
            if code == 126 {
                return Ok("N:cancelado".to_owned());
            }
            bail!("pkexec falhou ({}): {}", code, String::from_utf8_lossy(&o.stderr).trim());
        }
        Ok(out)
    }
}

// ---------------------------------------------------------------- outros (mobile/web)

#[cfg(not(any(windows, target_os = "macos", target_os = "linux")))]
mod imp {
    use super::Req;
    use hbb_common::{bail, ResultType};

    pub fn support() -> (bool, bool, String) {
        (false, false, "platform".to_owned())
    }
    pub fn apply(_r: &Req) -> ResultType<()> {
        bail!("não suportado nesta plataforma")
    }
    pub fn status() -> String {
        "unsupported".to_owned()
    }
    pub fn request(_r: Req) -> ResultType<String> {
        Ok("N:unsupported".to_owned())
    }
}
