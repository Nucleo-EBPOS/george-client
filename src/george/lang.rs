//! GEORGE: traduções próprias (pt-BR padrão + en). Consultadas antes das
//! tabelas upstream em `lang::translate_locale`, então também servem para
//! sobrescrever textos do upstream.
//!
//! Chaves novas começam com `george_` para não colidir com o upstream.

const PT_BR: &[(&str, &str)] = &[
    ("george_tagline", "your remote support"),
    ("george_your_id", "Seu ID"),
    ("george_copy_id", "Copiar ID"),
    ("george_id_copied", "ID copiado"),
    ("george_connect_to_id", "Conectar a um ID"),
    ("george_connect", "Conectar"),
    ("george_invite", "Convidar"),
    ("george_invite_title", "Convidar alguém para acessar este computador"),
    ("george_invite_desc", "Envie o código ou o link. O convite vale uma única vez e expira sozinho."),
    ("george_invite_code", "Código do convite"),
    ("george_invite_link", "Link do convite"),
    ("george_invite_copy_link", "Copiar link"),
    ("george_invite_copied", "Copiado"),
    ("george_invite_open_portal", "Abrir portal de convites"),
    ("george_invite_login_hint", "Entre na sua conta George para gerar convites por aqui, ou use o portal."),
    ("george_invite_failed", "Não foi possível gerar o convite. Tente novamente."),
    ("george_invite_expired", "Este convite expirou ou já foi usado. Peça um novo."),
    ("george_invite_invalid", "Convite inválido."),
    ("george_invite_consuming", "Validando convite..."),
    // GEORGE: vínculo à organização / acesso não-assistido (docs/specs/06)
    ("george_setup_this_pc", "Configurar este computador"),
    ("george_setup_title", "Configurar este computador"),
    ("george_setup_desc", "Escolha como este computador pode ser acessado pela equipe de TI. Dá para mudar depois."),
    ("george_unattended_title", "Acesso não-assistido"),
    ("george_unattended_desc", "A equipe de TI pode acessar este computador mesmo sem ninguém na frente dele, inclusive na tela de login do Windows. Inicia junto com o sistema."),
    ("george_unattended_need_install", "Instale o George neste computador para permitir o acesso não-assistido."),
    ("george_enroll_title", "Vincular à organização"),
    ("george_enroll_desc", "Cole o código que o administrador enviou (ou abra o link dele). O computador aparece no painel da empresa e a senha de acesso passa a ser gerida por ela. Este computador não vê nada da organização."),
    ("george_enroll_desc_done", "Este computador está vinculado. A senha de acesso é gerida pela organização; só o administrador pode desvincular."),
    ("george_enroll_button", "Vincular"),
    ("george_enroll_working", "Vinculando..."),
    ("george_enrolled_to", "Vinculado a"),
    ("george_enroll_err_format", "O código tem 12 caracteres, no formato XXXX-XXXX-XXXX."),
    ("george_enroll_err_invalid", "Código inválido, expirado ou já usado. Peça um novo ao administrador."),
    ("george_enroll_err_other_org", "Este computador já está vinculado a outra organização."),
    ("george_enroll_err_plan", "A organização atingiu o limite de computadores do plano."),
    ("george_enroll_err_revoked", "Este computador foi desvinculado pelo administrador."),
    ("george_enroll_err_timeout", "O serviço do George não respondeu. Verifique se ele está instalado e tente de novo."),
    ("george_enroll_err_network", "Sem conexão com o servidor do George. Verifique a internet e tente de novo."),
    ("george_advanced", "Avançado"),
    ("george_autologon_title", "Login automático do Windows"),
    ("george_autologon_desc", "Desligado (recomendado). Use só se o acesso pela tela de login não funcionar neste computador."),
    ("george_autologon_on", "Ligado para"),
    ("george_autologon_risk", "Atenção: com o login automático, o Windows entra sozinho nesta conta ao ligar. Qualquer pessoa com acesso físico ao computador fica logada nela, e a senha fica guardada (protegida) no próprio computador. Não use em servidores nem em contas de administrador."),
    ("george_autologon_user", "Usuário do Windows"),
    ("george_autologon_domain", "Domínio (opcional)"),
    ("george_autologon_password", "Senha do Windows"),
    ("george_autologon_accept", "Entendo o risco e quero ligar o login automático"),
    ("george_autologon_enable", "Ligar login automático"),
    ("george_autologon_failed", "Não foi possível alterar o login automático:"),
    ("george_org_devices", "Dispositivos da organização"),
    ("george_org_search", "Buscar por nome, setor ou ID"),
    ("george_org_empty", "Nenhum computador vinculado ainda."),
    ("george_org_load_failed", "Não foi possível carregar os dispositivos."),
    ("george_org_no_permission", "Você não tem permissão para acessar este computador."),
    ("george_org_connect_failed", "Não foi possível obter o acesso a este computador."),
    ("george_host_mode", "Modo Host"),
    ("george_host_on", "Modo Host: LIGADO"),
    ("george_host_off", "Modo Host: DESLIGADO"),
    ("george_host_desc_on", "Este computador aceita conexões de entrada."),
    ("george_host_desc_off", "Conexões de entrada recusadas. Você ainda pode acessar outros computadores."),
    ("george_host_status_online", "Online na sua conta"),
    ("george_host_status_accepting", "Aceitando conexões"),
    ("george_host_status_stopped", "Parado"),
    ("george_host_status_not_logged", "Sem conta (só por ID)"),
    ("george_host_starting", "Iniciando..."),
    ("george_account", "Conta"),
    ("george_sign_in", "Entrar"),
    ("george_sign_out", "Sair"),
    ("george_my_computers", "Meus computadores"),
    ("george_my_computers_hint", "Dispositivos da sua conta aparecem na aba Catálogo de endereços."),
    ("george_update_available", "Nova versão do George disponível"),
    ("george_update_download", "Baixar atualização"),
    ("george_about_credit", "O George é construído sobre o RustDesk (AGPL-3.0). Código-fonte disponível."),
    ("george_about_source", "Código-fonte"),
    ("george_website", "Site"),
    ("george_privacy", "Privacidade"),
    ("george_permanent_password", "Senha permanente"),
    ("george_one_time_password", "Senha de uso único"),
    ("george_show_password", "Mostrar senha"),
    ("george_connecting_invite", "Conectando pelo convite..."),
    ("george_theme", "Tema"),
    ("george_theme_system", "Sistema"),
    ("george_theme_light", "Claro"),
    ("george_theme_dark", "Escuro"),
    ("george_web_only_controller", "No navegador você só controla outros computadores."),
    // Sobrescritas de textos upstream
    ("Slogan_tip", "George — your remote support"),
    ("powered_by_me", ""),
    // GEORGE: textos de permissão do macOS, naturais e com a marca George.
    ("Permissions", "Permissões"),
    ("Configure", "Configurar"),
    ("Help", "Ajuda"),
    ("config_screen", "Para que outras pessoas acessem este computador, conceda ao George a permissão de \"Gravação de Tela\" nas Configurações do macOS."),
    ("config_acc", "Para que alguém controle este computador, conceda ao George a permissão de \"Acessibilidade\" nas Configurações do macOS."),
    ("config_input", "Para controle por teclado, conceda ao George a permissão de \"Monitoramento de Entrada\" nas Configurações do macOS."),
    ("config_microphone", "Para transmitir o áudio deste computador, conceda ao George a permissão de \"Gravar Áudio\"."),
    ("install_daemon_tip", "Para conexões não assistidas, instale o serviço em segundo plano do George."),
    ("doc_mac_permission", "https://georgedesk.com/ajuda/permissoes-macos"),
    ("Install", "Instalar"),
    ("Quit", "Sair"),
];

const EN: &[(&str, &str)] = &[
    ("george_tagline", "your remote support"),
    ("george_your_id", "Your ID"),
    ("george_copy_id", "Copy ID"),
    ("george_id_copied", "ID copied"),
    ("george_connect_to_id", "Connect to an ID"),
    ("george_connect", "Connect"),
    ("george_invite", "Invite"),
    ("george_invite_title", "Invite someone to access this computer"),
    ("george_invite_desc", "Share the code or the link. The invite works once and expires on its own."),
    ("george_invite_code", "Invite code"),
    ("george_invite_link", "Invite link"),
    ("george_invite_copy_link", "Copy link"),
    ("george_invite_copied", "Copied"),
    ("george_invite_open_portal", "Open invite portal"),
    ("george_invite_login_hint", "Sign in to your George account to create invites here, or use the portal."),
    ("george_invite_failed", "Could not create the invite. Please try again."),
    ("george_invite_expired", "This invite has expired or was already used. Ask for a new one."),
    ("george_invite_invalid", "Invalid invite."),
    ("george_invite_consuming", "Validating invite..."),
    ("george_setup_this_pc", "Set up this computer"),
    ("george_setup_title", "Set up this computer"),
    ("george_setup_desc", "Choose how the IT team can reach this computer. You can change it later."),
    ("george_unattended_title", "Unattended access"),
    ("george_unattended_desc", "The IT team can access this computer even when nobody is in front of it, including the Windows sign-in screen. Starts with the system."),
    ("george_unattended_need_install", "Install George on this computer to allow unattended access."),
    ("george_enroll_title", "Link to the organization"),
    ("george_enroll_desc", "Paste the code your administrator sent (or open their link). The computer shows up in the company panel and its access password is managed by the company. This computer cannot see anything from the organization."),
    ("george_enroll_desc_done", "This computer is linked. The access password is managed by the organization; only an administrator can unlink it."),
    ("george_enroll_button", "Link"),
    ("george_enroll_working", "Linking..."),
    ("george_enrolled_to", "Linked to"),
    ("george_enroll_err_format", "The code has 12 characters, formatted XXXX-XXXX-XXXX."),
    ("george_enroll_err_invalid", "Invalid, expired or used-up code. Ask your administrator for a new one."),
    ("george_enroll_err_other_org", "This computer is already linked to another organization."),
    ("george_enroll_err_plan", "The organization reached its plan's computer limit."),
    ("george_enroll_err_revoked", "This computer was unlinked by the administrator."),
    ("george_enroll_err_timeout", "The George service did not respond. Make sure it is installed and try again."),
    ("george_enroll_err_network", "Cannot reach the George server. Check the internet connection and try again."),
    ("george_advanced", "Advanced"),
    ("george_autologon_title", "Windows automatic sign-in"),
    ("george_autologon_desc", "Off (recommended). Only use it if access through the sign-in screen does not work on this computer."),
    ("george_autologon_on", "On for"),
    ("george_autologon_risk", "Warning: with automatic sign-in, Windows signs into this account by itself at startup. Anyone with physical access gets that session, and the password is stored (protected) on this computer. Do not use it on servers or administrator accounts."),
    ("george_autologon_user", "Windows user"),
    ("george_autologon_domain", "Domain (optional)"),
    ("george_autologon_password", "Windows password"),
    ("george_autologon_accept", "I understand the risk and want automatic sign-in"),
    ("george_autologon_enable", "Turn on automatic sign-in"),
    ("george_autologon_failed", "Could not change automatic sign-in:"),
    ("george_org_devices", "Organization devices"),
    ("george_org_search", "Search by name, department or ID"),
    ("george_org_empty", "No linked computers yet."),
    ("george_org_load_failed", "Could not load the devices."),
    ("george_org_no_permission", "You are not allowed to access this computer."),
    ("george_org_connect_failed", "Could not get access to this computer."),
    ("george_host_mode", "Host Mode"),
    ("george_host_on", "Host Mode: ON"),
    ("george_host_off", "Host Mode: OFF"),
    ("george_host_desc_on", "This computer accepts incoming connections."),
    ("george_host_desc_off", "Incoming connections refused. You can still access other computers."),
    ("george_host_status_online", "Online in your account"),
    ("george_host_status_accepting", "Accepting connections"),
    ("george_host_status_stopped", "Stopped"),
    ("george_host_status_not_logged", "No account (ID only)"),
    ("george_host_starting", "Starting..."),
    ("george_account", "Account"),
    ("george_sign_in", "Sign in"),
    ("george_sign_out", "Sign out"),
    ("george_my_computers", "My computers"),
    ("george_my_computers_hint", "Devices in your account show up in the Address book tab."),
    ("george_update_available", "A new George version is available"),
    ("george_update_download", "Download update"),
    ("george_about_credit", "George is built on top of RustDesk (AGPL-3.0). Source code available."),
    ("george_about_source", "Source code"),
    ("george_website", "Website"),
    ("george_privacy", "Privacy"),
    ("george_permanent_password", "Permanent password"),
    ("george_one_time_password", "One-time password"),
    ("george_show_password", "Show password"),
    ("george_connecting_invite", "Connecting through the invite..."),
    ("george_theme", "Theme"),
    ("george_theme_system", "System"),
    ("george_theme_light", "Light"),
    ("george_theme_dark", "Dark"),
    ("george_web_only_controller", "In the browser you can only control other computers."),
    ("Slogan_tip", "George — your remote support"),
    ("powered_by_me", ""),
    ("config_screen", "To let others access this computer, grant George the \"Screen Recording\" permission in macOS Settings."),
    ("config_acc", "To let someone control this computer, grant George the \"Accessibility\" permission in macOS Settings."),
    ("config_input", "For keyboard control, grant George the \"Input Monitoring\" permission in macOS Settings."),
    ("config_microphone", "To stream this computer's audio, grant George the \"Record Audio\" permission."),
    ("install_daemon_tip", "For unattended access, install George's background service."),
    ("doc_mac_permission", "https://georgedesk.com/ajuda/permissoes-macos"),
];

fn lookup(table: &[(&str, &str)], name: &str) -> Option<String> {
    table
        .iter()
        .find(|(k, _)| *k == name)
        .map(|(_, v)| (*v).to_owned())
}

/// Tradução do overlay George para `lang` (código já resolvido pelo upstream,
/// ex.: "pt-br", "en"). Retorna `None` quando a chave não é do George.
pub fn translate(lang: &str, name: &str) -> Option<String> {
    let is_pt = lang == "br" || lang.starts_with("pt");
    let is_en = lang == "en" || lang.starts_with("en");
    // Chaves próprias do George (`george_*`) existem só aqui: sempre pt-BR, com
    // en como fallback para qualquer outro idioma.
    let is_george_key = name.starts_with("george_");
    if is_pt {
        if let Some(v) = lookup(PT_BR, name) {
            return Some(v);
        }
    }
    if is_pt || is_en || is_george_key {
        return lookup(EN, name);
    }
    // Para outros idiomas, só sobrescrevemos as chaves próprias do George;
    // o resto fica com a tradução nativa do upstream.
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pt_br_default_and_en_fallback() {
        assert_eq!(translate("pt-br", "george_invite").as_deref(), Some("Convidar"));
        assert_eq!(translate("en", "george_invite").as_deref(), Some("Invite"));
        assert_eq!(translate("de", "george_invite").as_deref(), Some("Invite"));
        assert!(translate("pt-br", "Not a george key").is_none());
        // override de chave upstream vale em pt/en, não em outros idiomas
        assert!(translate("pt-br", "Configure").is_some());
        assert!(translate("en", "Configure").is_some());
        assert!(translate("de", "Configure").is_none());
    }

    #[test]
    fn every_pt_key_has_en() {
        for (k, _) in PT_BR {
            assert!(lookup(EN, k).is_some(), "missing en for {k}");
        }
    }
}
