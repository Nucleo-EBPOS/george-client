//! GEORGE: login automático do Windows (opção AVANÇADA, desligada por padrão).
//!
//! Só existe para o caso em que a tela de login remota não basta. A senha do
//! Windows vai como segredo LSA (`DefaultPassword`, igual ao Sysinternals
//! Autologon) — nunca em texto puro no registro nem no Config do George.
//! A UI (usuário comum) pede pelo IPC; quem grava é o serviço (SYSTEM).
//! O valor do IPC não é persistido em lugar nenhum.
use serde::Deserialize;
#[cfg(windows)]
use hbb_common::tokio;

/// Nome da mensagem `Data::Config` no IPC.
pub const IPC_KEY: &str = "george-autologon";

#[derive(Debug, Default, Deserialize)]
struct Req {
    #[serde(default)]
    user: String,
    #[serde(default)]
    domain: String,
    #[serde(default)]
    password: String,
}

/// Estado para a UI: "on:<DOMÍNIO\usuário>", "off" ou "unsupported".
#[cfg(windows)]
pub fn status() -> String {
    imp::status()
}

#[cfg(not(windows))]
pub fn status() -> String {
    "unsupported".to_owned()
}

/// Lado do serviço: aplica o pedido vindo do IPC. Usuário vazio = desligar.
/// Devolve "Y" ou "N:<erro>".
#[cfg(windows)]
pub fn apply_from_ipc(value: &str) -> String {
    let r = match serde_json::from_str::<Req>(value) {
        Ok(r) => r,
        Err(e) => return format!("N:{}", e),
    };
    match imp::set(&r) {
        Ok(()) => {
            hbb_common::log::info!(
                "george autologon: {}",
                if r.user.is_empty() { "desligado" } else { "ligado" }
            );
            "Y".to_owned()
        }
        Err(e) => {
            hbb_common::log::error!("george autologon: {}", e);
            format!("N:{}", e)
        }
    }
}

#[cfg(not(windows))]
pub fn apply_from_ipc(_value: &str) -> String {
    "N:unsupported".to_owned()
}

/// Lado da UI: pede ao serviço. Devolve "Y" ou "N:<erro>".
#[cfg(windows)]
pub fn request(user: String, domain: String, password: String) -> String {
    let v = serde_json::json!({ "user": user, "domain": domain, "password": password });
    match request_async(v.to_string()) {
        Ok(s) => s,
        Err(e) => format!("N:{}", e),
    }
}

#[cfg(not(windows))]
pub fn request(_user: String, _domain: String, _password: String) -> String {
    "N:unsupported".to_owned()
}

#[cfg(windows)]
#[tokio::main(flavor = "current_thread")]
async fn request_async(value: String) -> hbb_common::ResultType<String> {
    use crate::ipc::Data;
    let mut c = crate::ipc::connect(1_000, "").await?;
    c.send(&Data::Config((IPC_KEY.to_owned(), Some(value)))).await?;
    if let Some(Data::Config((name, Some(v)))) = c.next_timeout(5_000).await? {
        if name == IPC_KEY {
            return Ok(v);
        }
    }
    Ok("N:sem resposta do serviço".to_owned())
}

#[cfg(windows)]
mod imp {
    use super::Req;
    use hbb_common::{bail, ResultType};
    use std::ffi::c_void;
    use winreg::{enums::*, RegKey};

    const WINLOGON: &str = r"SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon";
    const POLICY_CREATE_SECRET: u32 = 0x0000_0020;

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
    }

    fn lsa_string(v: &mut Vec<u16>) -> LsaUnicodeString {
        let bytes = (v.len() * 2) as u16;
        LsaUnicodeString {
            length: bytes,
            maximum_length: bytes,
            buffer: v.as_mut_ptr(),
        }
    }

    /// Grava (Some) ou apaga (None) o segredo LSA `DefaultPassword`.
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
            let st = LsaOpenPolicy(
                std::ptr::null_mut(),
                &mut attrs,
                POLICY_CREATE_SECRET,
                &mut handle,
            );
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
        // zera a cópia em memória
        for c in data.iter_mut() {
            *c = 0;
        }
        Ok(())
    }

    pub fn set(r: &Req) -> ResultType<()> {
        let hklm = RegKey::predef(HKEY_LOCAL_MACHINE);
        let key = hklm.open_subkey_with_flags(WINLOGON, KEY_READ | KEY_WRITE)?;
        // Nunca deixar senha em texto puro no registro (Winlogon também lê DefaultPassword dali).
        let _ = key.delete_value("DefaultPassword");
        if r.user.trim().is_empty() {
            key.set_value("AutoAdminLogon", &"0")?;
            lsa_store_default_password(None)?;
            return Ok(());
        }
        if r.password.is_empty() {
            bail!("senha vazia");
        }
        lsa_store_default_password(Some(&r.password))?;
        key.set_value("DefaultUserName", &r.user.trim())?;
        key.set_value("DefaultDomainName", &r.domain.trim())?;
        key.set_value("AutoAdminLogon", &"1")?;
        // Sem limite de vezes (AutoLogonCount desligaria depois de N logons).
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
}
