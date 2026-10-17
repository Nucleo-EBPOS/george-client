//! GEORGE: configuração embutida do cliente George (fork rebrandizado do RustDesk).
//!
//! Tudo que é específico do George no lado Rust vive aqui. Os pontos de
//! contato com o core upstream são mínimos e marcados com `// GEORGE:`.
//!
//! Os valores de produção podem ser sobrescritos em tempo de build pelas
//! variáveis de ambiente `RENDEZVOUS_SERVER`, `RELAY_SERVER`, `API_SERVER` e
//! `RS_PUB_KEY` (mesmos nomes dos hooks oficiais do RustDesk). Sem elas, os
//! valores abaixo (produção) são usados.
use hbb_common::config;

pub mod lang;

pub const APP_NAME: &str = "George";
pub const ORG: &str = "com.georgedesk";
pub const SITE_URL: &str = "https://georgedesk.com";
pub const PRIVACY_URL: &str = "https://georgedesk.com/privacidade";
pub const UPDATE_URL: &str = "https://georgedesk.com/api/v1/releases/latest";
/// Clientes customizados do upstream não checam atualização; o George checa.
pub const CHECK_UPDATES: bool = true;
/// Repositório GitHub onde os releases são publicados (owner, repo).
pub const RELEASE_REPO: (&str, &str) = ("Nucleo-EBPOS", "george-client");

pub const RENDEZVOUS_SERVER: &str = match option_env!("RENDEZVOUS_SERVER") {
    Some(v) => v,
    None => "georgedesk.com",
};
pub const RELAY_SERVER: &str = match option_env!("RELAY_SERVER") {
    Some(v) => v,
    None => "georgedesk.com:21117",
};
pub const API_SERVER: &str = match option_env!("API_SERVER") {
    Some(v) => v,
    None => "https://georgedesk.com",
};
pub const RS_PUB_KEY: &str = match option_env!("RS_PUB_KEY") {
    Some(v) => v,
    None => "GuScaZGLwh+xwwBVafvVItAJsbjNf+zT7tBEUWCIwqo=",
};

/// Opção avançada escondida para desenvolvimento: com `GEORGE_DEV_SERVER=1`
/// no ambiente do processo, o servidor/chave deixam de ser travados e podem
/// ser editados nas configurações de rede.
pub fn dev_server_unlocked() -> bool {
    std::env::var("GEORGE_DEV_SERVER")
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false)
}

/// Aplica a identidade e a configuração de produção do George.
/// Chamado por `load_custom_client()` (todos os processos: UI, serviço, tray,
/// mobile). Idempotente.
pub fn apply() {
    *config::APP_NAME.write().unwrap() = APP_NAME.to_owned();
    *config::ORG.write().unwrap() = ORG.to_owned();
    *config::PROD_RENDEZVOUS_SERVER.write().unwrap() = RENDEZVOUS_SERVER.to_owned();

    if !dev_server_unlocked() {
        // Mesmo mecanismo dos "override-settings" do cliente customizado
        // oficial: o usuário não consegue apontar para outro servidor.
        let mut ow = config::OVERWRITE_SETTINGS.write().unwrap();
        ow.insert("custom-rendezvous-server".to_owned(), RENDEZVOUS_SERVER.to_owned());
        ow.insert("relay-server".to_owned(), RELAY_SERVER.to_owned());
        ow.insert("api-server".to_owned(), API_SERVER.to_owned());
        ow.insert("key".to_owned(), RS_PUB_KEY.to_owned());
    }

    let mut builtin = config::BUILTIN_SETTINGS.write().unwrap();
    builtin.insert("hide-powered-by-me".to_owned(), "Y".to_owned());
    builtin.insert("remove-preset-password-warning".to_owned(), "Y".to_owned());
    if !dev_server_unlocked() {
        builtin.insert("hide-server-settings".to_owned(), "Y".to_owned());
    }
}

/// `true` quando `owner/repo` é um repositório de releases aceito pelo
/// verificador de atualização (o do George e, por compatibilidade, o upstream).
pub fn is_release_repo(owner: &str, repo: &str) -> bool {
    (owner, repo) == RELEASE_REPO || (owner, repo) == ("rustdesk", "rustdesk")
}

/// Modo Host ligado = serviço aceitando conexões de entrada
/// (a opção nativa `stop-service` não está ativa).
pub fn host_mode_enabled() -> bool {
    // Lê o arquivo (a bandeja roda em outro processo e não vê o CONFIG2 da UI).
    let fresh = config::load_path::<config::Config2>(config::Config2::file());
    let v = fresh
        .options
        .get("stop-service")
        .cloned()
        .unwrap_or_else(|| config::Config::get_option("stop-service"));
    !config::option2bool("stop-service", &v)
}

/// Texto curto de estado do Modo Host para a bandeja.
#[cfg(not(any(target_os = "android", target_os = "ios")))]
pub fn host_mode_status() -> String {
    let key = if host_mode_enabled() {
        "george_host_on"
    } else {
        "george_host_off"
    };
    crate::lang::translate(key.to_owned())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn release_repo() {
        assert!(is_release_repo("Nucleo-EBPOS", "george-client"));
        assert!(is_release_repo("rustdesk", "rustdesk"));
        assert!(!is_release_repo("rustdesk", "other"));
    }

    #[test]
    fn defaults_are_production() {
        assert_eq!(RENDEZVOUS_SERVER, "georgedesk.com");
        assert!(API_SERVER.starts_with("https://"));
        assert_eq!(RS_PUB_KEY.len(), 44);
    }
}
