//! GEORGE: agente de vínculo (enrollment) e acesso não-assistido.
//!
//! Roda no processo `--server` (o que existe mesmo sem usuário logado e é o dono
//! do `Config`). Contrato: `docs/specs/06-enrollment.md` no monorepo `george`.
//!
//! - Vincula o PC a uma organização com um código (`POST /api/v1/enroll`).
//! - Mantém presença e recebe a senha permanente gerida pela org
//!   (`POST /api/v1/agent/heartbeat`, `Authorization: Device <token>`).
//! - Revogado no painel (410) → apaga token e senha permanente.
//!
//! O token do dispositivo NUNCA vai para as `options` (qualquer usuário local as
//! lê pelo IPC): fica em `George_agent.toml` no diretório de configuração do
//! serviço. Para a UI só vão textos de estado, sem segredos (`OPT_*`).
use hbb_common::{
    anyhow::anyhow,
    bail,
    config::{self, Config},
    log, tokio, ResultType,
};
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    path::PathBuf,
    time::{Duration, Instant},
};

/// Código pendente, gravado pela UI (IPC) e consumido pelo agente.
pub const OPT_ENROLL_CODE: &str = "george-enroll-code";
/// Estado do último vínculo para a UI: "", "pending", "ok", "error:<code>:<mensagem>".
pub const OPT_ENROLL_STATUS: &str = "george-enroll-status";
/// "Y" quando vinculado (o resto vem nos campos abaixo).
pub const OPT_ENROLLED: &str = "george-enrolled";
pub const OPT_ORG_NAME: &str = "george-org-name";
pub const OPT_DEVICE_NAME: &str = "george-device-name";
pub const OPT_GROUP_NAME: &str = "george-group-name";

const STATE_FILE: &str = "George_agent.toml";
const TICK: Duration = Duration::from_secs(2);
const DEFAULT_INTERVAL: u64 = 60;
/// Nos primeiros minutos depois de vincular/iniciar, o heartbeat é mais frequente
/// (o painel mostra "online" e a senha aplicada quase na hora).
const FAST_INTERVAL: u64 = 15;
const FAST_WINDOW: Duration = Duration::from_secs(120);
const SYSINFO_REFRESH: Duration = Duration::from_secs(600);

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct AgentState {
    #[serde(default)]
    pub device_token: String,
    #[serde(default)]
    pub device_row_id: u64,
    #[serde(default)]
    pub org_name: String,
    #[serde(default)]
    pub device_name: String,
    #[serde(default)]
    pub group_name: String,
    /// Versão da senha permanente aplicada neste PC.
    #[serde(default)]
    pub password_version: i64,
}

impl AgentState {
    fn file() -> PathBuf {
        Config::path(STATE_FILE)
    }

    pub fn load() -> Self {
        config::load_path::<AgentState>(Self::file())
    }

    fn store(&self) {
        let path = Self::file();
        if let Err(err) = config::store_path(path.clone(), self) {
            log::error!("george agent: falha ao gravar {:?}: {}", path, err);
        }
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600)).ok();
        }
    }

    pub fn enrolled(&self) -> bool {
        !self.device_token.is_empty()
    }
}

/// Arquivo de provisionamento gravado pelo MSI/instalador/`--enroll` (contém segredo;
/// apagado depois de lido). Só administradores escrevem nesse diretório.
#[cfg(windows)]
pub fn provision_file() -> PathBuf {
    let base = std::env::var("ProgramData").unwrap_or_else(|_| "C:\\ProgramData".to_owned());
    PathBuf::from(base).join("George").join("provision.toml")
}

#[cfg(target_os = "macos")]
pub fn provision_file() -> PathBuf {
    PathBuf::from("/Library/Application Support/George/provision.toml")
}

#[cfg(not(any(windows, target_os = "macos")))]
pub fn provision_file() -> PathBuf {
    PathBuf::from("/etc/george/provision.toml")
}

#[derive(Debug, Default, Clone, Serialize, Deserialize)]
pub struct Provision {
    #[serde(default)]
    pub enroll_code: String,
    /// Senha permanente fixada pela org na instalação (opcional; sem ela a API gera uma).
    #[serde(default)]
    pub password: String,
    /// "1"/"0" (MSI) ou true/false; vazio = não mexe.
    #[serde(default)]
    pub unattended: String,
}

/// Grava o arquivo de provisionamento (usado por `--enroll` na linha de comando).
pub fn write_provision(p: &Provision) -> ResultType<PathBuf> {
    let path = provision_file();
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    let s = hbb_common::toml::to_string(p)?;
    std::fs::write(&path, s)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        std::fs::set_permissions(&path, std::fs::Permissions::from_mode(0o600)).ok();
    }
    Ok(path)
}

fn take_provision() -> Option<Provision> {
    let path = provision_file();
    if !path.exists() {
        return None;
    }
    let p = std::fs::read_to_string(&path)
        .ok()
        .and_then(|s| hbb_common::toml::from_str::<Provision>(&s).ok());
    // Apaga sempre (mesmo inválido) para não ficar segredo no disco nem repetir em loop.
    if let Err(err) = std::fs::remove_file(&path) {
        log::warn!("george agent: não consegui apagar {:?}: {}", path, err);
    }
    if p.is_none() {
        log::warn!("george agent: {:?} inválido, ignorado", path);
    }
    p
}

fn api_base() -> String {
    crate::common::get_api_server(
        Config::get_option("api-server"),
        Config::get_option("custom-rendezvous-server"),
    )
}

fn set_status(s: &str) {
    Config::set_option(OPT_ENROLL_STATUS.to_owned(), s.to_owned());
}

fn publish_state(st: &AgentState) {
    let enrolled = if st.enrolled() { "Y" } else { "" };
    for (k, v) in [
        (OPT_ENROLLED, enrolled),
        (OPT_ORG_NAME, st.org_name.as_str()),
        (OPT_DEVICE_NAME, st.device_name.as_str()),
        (OPT_GROUP_NAME, st.group_name.as_str()),
    ] {
        if Config::get_option(k) != v {
            Config::set_option(k.to_owned(), v.to_owned());
        }
    }
}

fn unattended_on() -> bool {
    !config::option2bool("stop-service", &Config::get_option("stop-service"))
}

fn set_unattended(on: bool) {
    Config::set_option("stop-service".to_owned(), if on { "" } else { "Y" }.to_owned());
}

/// Garante que a senha permanente seja aceita: sem "só clique" e sem "só senha temporária".
fn ensure_password_accepted() {
    if Config::get_option("approve-mode") == "click" {
        Config::set_option("approve-mode".to_owned(), "".to_owned());
    }
    if Config::get_option("verification-method") == "use-temporary-password" {
        Config::set_option("verification-method".to_owned(), "".to_owned());
    }
}

fn apply_password(st: &mut AgentState, v: &Value) -> bool {
    let version = v["version"].as_i64().unwrap_or(0);
    let value = v["value"].as_str().unwrap_or_default();
    if version <= 0 || value.is_empty() {
        return false;
    }
    if !Config::set_permanent_password(value) {
        log::error!("george agent: senha permanente v{} recusada pelo Config", version);
        return false;
    }
    ensure_password_accepted();
    st.password_version = version;
    log::info!("george agent: senha permanente v{} aplicada", version);
    true
}

struct SysInfo {
    hostname: String,
    os: String,
    username: String,
}

fn sysinfo() -> SysInfo {
    let v = crate::get_sysinfo();
    SysInfo {
        hostname: v["hostname"].as_str().unwrap_or_default().to_owned(),
        os: v["os"].as_str().unwrap_or_default().to_owned(),
        username: v["username"].as_str().unwrap_or_default().to_owned(),
    }
}

fn platform() -> &'static str {
    if cfg!(windows) {
        "windows"
    } else if cfg!(target_os = "macos") {
        "macos"
    } else {
        "linux"
    }
}

fn error_code(body: &str) -> (String, String) {
    let v: Value = serde_json::from_str(body).unwrap_or(Value::Null);
    let e = &v["error"];
    (
        e["code"].as_str().unwrap_or("http_error").to_owned(),
        e["message"].as_str().unwrap_or_default().to_owned(),
    )
}

async fn enroll(st: &mut AgentState, code: &str, password: &str, si: &SysInfo) -> ResultType<()> {
    let base = api_base();
    if base.is_empty() {
        bail!("api_unavailable");
    }
    let mut body = json!({
        "code": code.trim().to_uppercase(),
        "rustdesk_id": Config::get_id(),
        "uuid": crate::ui_interface::get_uuid(),
        "hostname": si.hostname,
        "platform": platform(),
        "os": si.os,
        "version": super::version(),
        "username": si.username,
    });
    if !password.is_empty() {
        body["password"] = json!(password);
    }
    let (status, text) = crate::common::post_request_with_status(
        format!("{}/api/v1/enroll", base),
        body.to_string(),
        "",
    )
    .await?;
    if !(200..300).contains(&status) {
        let (c, m) = error_code(&text);
        bail!("{}:{}", c, m);
    }
    let v: Value = serde_json::from_str(&text)?;
    let v = if v["data"].is_object() { v["data"].clone() } else { v };
    let token = v["device_token"].as_str().unwrap_or_default();
    if token.is_empty() {
        bail!("bad_response:sem device_token");
    }
    st.device_token = token.to_owned();
    st.device_row_id = v["device"]["id"].as_u64().unwrap_or(0);
    st.device_name = v["device"]["name"].as_str().unwrap_or_default().to_owned();
    st.group_name = v["device"]["group_name"].as_str().unwrap_or_default().to_owned();
    st.org_name = v["org"]["name"].as_str().unwrap_or_default().to_owned();
    st.password_version = 0;
    apply_password(st, &v["password"]);
    st.store();
    log::info!(
        "george agent: vinculado a '{}' como '{}' (device {})",
        st.org_name,
        st.device_name,
        st.device_row_id
    );
    Ok(())
}

enum Beat {
    Alive(u64),
    Revoked,
}

async fn heartbeat(st: &mut AgentState, si: &SysInfo) -> ResultType<Beat> {
    let base = api_base();
    if base.is_empty() {
        bail!("api_unavailable");
    }
    let body = json!({
        "rustdesk_id": Config::get_id(),
        "uuid": crate::ui_interface::get_uuid(),
        "hostname": si.hostname,
        "os": si.os,
        "version": super::version(),
        "unattended": unattended_on(),
        "password_version": st.password_version,
    });
    let (status, text) = crate::common::post_request_with_status(
        format!("{}/api/v1/agent/heartbeat", base),
        body.to_string(),
        &format!("Authorization: Device {}", st.device_token),
    )
    .await?;
    if status == 410 || status == 401 {
        let (c, _) = error_code(&text);
        // 401 só conta como revogado com o código explícito (proxy/rede não derruba o vínculo).
        if status == 410 || c == "device_token_invalid" {
            return Ok(Beat::Revoked);
        }
    }
    if !(200..300).contains(&status) {
        let (c, m) = error_code(&text);
        return Err(anyhow!("{}:{}", c, m));
    }
    let v: Value = serde_json::from_str(&text)?;
    let v = if v["data"].is_object() { v["data"].clone() } else { v };
    let mut changed = false;
    for (field, slot) in [
        ("name", &mut st.device_name),
        ("group_name", &mut st.group_name),
        ("org_name", &mut st.org_name),
    ] {
        if let Some(s) = v[field].as_str() {
            if *slot != s {
                *slot = s.to_owned();
                changed = true;
            }
        }
    }
    if v["password"].is_object() && apply_password(st, &v["password"]) {
        changed = true;
    }
    if changed {
        st.store();
    }
    Ok(Beat::Alive(v["heartbeat_interval"].as_u64().unwrap_or(DEFAULT_INTERVAL)))
}

fn wipe(st: &mut AgentState) {
    log::warn!("george agent: dispositivo revogado na organização; removendo vínculo e senha permanente");
    *st = AgentState::default();
    st.store();
    Config::set_permanent_password("");
}

/// Inicia o agente (uma vez por processo).
pub fn start() {
    use std::sync::Once;
    static ONCE: Once = Once::new();
    ONCE.call_once(|| {
        std::thread::Builder::new()
            .name("george-agent".into())
            .spawn(run)
            .ok();
    });
}

#[tokio::main(flavor = "current_thread")]
async fn run() {
    let mut st = AgentState::load();
    publish_state(&st);
    let started = Instant::now();
    let mut si = sysinfo();
    let mut si_at = Instant::now();
    let mut next_beat = Instant::now();
    let mut interval = DEFAULT_INTERVAL;
    loop {
        // 1) provisionamento (MSI / --enroll) e 2) código vindo da UI
        let mut job: Option<(String, String)> = None;
        if let Some(p) = take_provision() {
            match p.unattended.trim().to_lowercase().as_str() {
                "1" | "true" | "y" | "yes" | "on" => set_unattended(true),
                "0" | "false" | "n" | "no" | "off" => set_unattended(false),
                _ => {}
            }
            if !p.enroll_code.trim().is_empty() {
                job = Some((p.enroll_code, p.password));
            } else if !p.password.is_empty() {
                // só senha (sem vínculo): aplica localmente
                if Config::set_permanent_password(&p.password) {
                    ensure_password_accepted();
                }
            }
        }
        let ui_code = Config::get_option(OPT_ENROLL_CODE);
        if job.is_none() && !ui_code.trim().is_empty() {
            job = Some((ui_code, String::new()));
        }
        if !Config::get_option(OPT_ENROLL_CODE).is_empty() {
            Config::set_option(OPT_ENROLL_CODE.to_owned(), "".to_owned());
        }
        if let Some((code, pw)) = job {
            set_status("pending");
            si = sysinfo();
            si_at = Instant::now();
            match enroll(&mut st, &code, &pw, &si).await {
                Ok(()) => {
                    set_status("ok");
                    publish_state(&st);
                    next_beat = Instant::now() + Duration::from_secs(FAST_INTERVAL);
                }
                Err(err) => {
                    log::error!("george agent: vínculo falhou: {}", err);
                    set_status(&format!("error:{}", err));
                }
            }
        }

        // 3) heartbeat
        if st.enrolled() && Instant::now() >= next_beat {
            if si_at.elapsed() > SYSINFO_REFRESH {
                si = sysinfo();
                si_at = Instant::now();
            }
            match heartbeat(&mut st, &si).await {
                Ok(Beat::Alive(n)) => {
                    interval = n.clamp(10, 3600);
                    publish_state(&st);
                }
                Ok(Beat::Revoked) => {
                    wipe(&mut st);
                    publish_state(&st);
                    set_status("error:device_revoked:");
                }
                Err(err) => log::warn!("george agent: heartbeat falhou: {}", err),
            }
            let secs = if started.elapsed() < FAST_WINDOW {
                interval.min(FAST_INTERVAL)
            } else {
                interval
            };
            next_beat = Instant::now() + Duration::from_secs(secs);
        }
        tokio::time::sleep(TICK).await;
    }
}

// ---------------------------------------------------------------- linha de comando

#[cfg(windows)]
fn restrict_provision_dir(dir: &std::path::Path) {
    // Só SYSTEM e Administradores (o arquivo carrega código de vínculo/senha).
    let d = dir.to_string_lossy().to_string();
    let _ = std::process::Command::new("icacls")
        .args([
            d.as_str(),
            "/inheritance:r",
            "/grant:r",
            "*S-1-5-18:(OI)(CI)F",
            "*S-1-5-32-544:(OI)(CI)F",
        ])
        .output();
}

/// `George --enroll <CODE> [--password <PW>] [--unattended on|off]`
/// e `George --unattended on|off`. Precisa de instalação + administrador/root.
/// Grava o provisionamento e espera o agente do serviço aplicar. Devolve o exit code.
pub fn cli(args: &[String]) -> i32 {
    let mut p = Provision::default();
    let mut i = 0;
    while i < args.len() {
        let a = args[i].as_str();
        let next = args.get(i + 1).cloned().unwrap_or_default();
        match a {
            "--enroll" => {
                p.enroll_code = next;
                i += 1;
            }
            "--password" => {
                p.password = next;
                i += 1;
            }
            "--unattended" => {
                p.unattended = next;
                i += 1;
            }
            _ => {}
        }
        i += 1;
    }
    if p.enroll_code.is_empty() && p.unattended.is_empty() && p.password.is_empty() {
        println!("uso: George --enroll <CÓDIGO> [--password <SENHA>] [--unattended on|off]");
        return 2;
    }
    if !(crate::platform::is_installed() && crate::platform::is_root()) {
        println!("Requer o George instalado e privilégios de administrador.");
        return 1;
    }
    if !p.password.is_empty() && p.password.chars().count() < 8 {
        println!("A senha permanente precisa ter ao menos 8 caracteres.");
        return 2;
    }
    let enrolling = !p.enroll_code.is_empty();
    if enrolling {
        crate::ipc::set_option(OPT_ENROLL_STATUS, "");
    }
    match write_provision(&p) {
        Ok(path) => {
            #[cfg(windows)]
            if let Some(dir) = path.parent() {
                restrict_provision_dir(dir);
            }
            log::info!("george cli: provisionamento gravado em {:?}", path);
        }
        Err(err) => {
            println!("Falha ao gravar o provisionamento: {}", err);
            return 1;
        }
    }
    cli_wait(enrolling)
}

#[tokio::main(flavor = "current_thread")]
async fn cli_wait(enrolling: bool) -> i32 {
    let deadline = Instant::now() + Duration::from_secs(30);
    loop {
        if !provision_file().exists() {
            if !enrolling {
                println!("OK");
                return 0;
            }
            let o = crate::ipc::get_options_async().await;
            let status = o.get(OPT_ENROLL_STATUS).cloned().unwrap_or_default();
            if status == "ok" {
                println!(
                    "OK vinculado a \"{}\" como \"{}\"",
                    o.get(OPT_ORG_NAME).cloned().unwrap_or_default(),
                    o.get(OPT_DEVICE_NAME).cloned().unwrap_or_default()
                );
                return 0;
            }
            if let Some(e) = status.strip_prefix("error:") {
                println!("ERRO {}", e);
                return 1;
            }
        }
        if Instant::now() > deadline {
            println!("Provisionamento gravado; será aplicado quando o serviço George estiver rodando.");
            return 0;
        }
        tokio::time::sleep(Duration::from_millis(500)).await;
    }
}
