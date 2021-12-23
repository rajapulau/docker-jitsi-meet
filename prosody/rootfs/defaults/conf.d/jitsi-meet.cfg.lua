admins = {
    "{{ .Env.JICOFO_AUTH_USER }}@{{ .Env.XMPP_AUTH_DOMAIN }}",
    "{{ .Env.JVB_AUTH_USER }}@{{ .Env.XMPP_AUTH_DOMAIN }}"
}

plugin_paths = { "/prosody-plugins/", "/prosody-plugins-custom" }
http_default_host = "{{ .Env.XMPP_DOMAIN }}"
muc_mapper_domain_prefix = "muc"
muc_mapper_domain_base = "{{ .Env.XMPP_DOMAIN }}"

{{ $DISABLE_POLLS := .Env.DISABLE_POLLS | default "false" | toBool -}}
{{ $ENABLE_AUTH := .Env.ENABLE_AUTH | default "0" | toBool -}}
{{ $ENABLE_BREAKOUT_ROOMS := .Env.ENABLE_BREAKOUT_ROOMS | default "1" | toBool }}
{{ $ENABLE_GUEST_DOMAIN := and $ENABLE_AUTH (.Env.ENABLE_GUESTS | default "0" | toBool) -}}
{{ $AUTH_TYPE := .Env.AUTH_TYPE | default "internal" -}}
{{ $JWT_ASAP_KEYSERVER := .Env.JWT_ASAP_KEYSERVER | default "" -}}
{{ $JWT_ALLOW_EMPTY := .Env.JWT_ALLOW_EMPTY | default "0" | toBool -}}
{{ $JWT_AUTH_TYPE := .Env.JWT_AUTH_TYPE | default "token" }}
{{ $JWT_TOKEN_AUTH_MODULE := .Env.JWT_TOKEN_AUTH_MODULE | default "token_verification" -}}
{{ $ENABLE_LOBBY := .Env.ENABLE_LOBBY | default "0" | toBool -}}
{{ $ENABLE_XMPP_WEBSOCKET := .Env.ENABLE_XMPP_WEBSOCKET | default "1" | toBool -}}
{{ $ENABLE_SUBDOMAINS := .Env.ENABLE_SUBDOMAINS | default "false" -}}
{{ $PUBLIC_URL := .Env.PUBLIC_URL | default "https://localhost:8443" -}}
{{ $TURN_PORT := .Env.TURN_PORT | default "443" }}
{{ $TURNS_PORT := .Env.TURNS_PORT | default "443" }}
{{ $ENABLE_MEET_STATS := .Env.ENABLE_MEET_STATS | default "0" | toBool -}}

{{ if .Env.TURN_CREDENTIALS }}
external_service_secret = "{{.Env.TURN_CREDENTIALS}}";
{{ end }}

{{ if or .Env.TURN_HOST .Env.TURNS_HOST }}
external_services = {
  {{ if .Env.TURN_HOST }}
     { type = "turn", host = "{{ .Env.TURN_HOST }}", port = {{ $TURN_PORT }}, transport = "tcp", secret = true, ttl = 86400, algorithm = "turn" }
  {{ end }}
  {{ if and .Env.TURN_HOST .Env.TURNS_HOST }}
  ,
  {{ end }}
  {{ if .Env.TURNS_HOST }}
     { type = "turns", host = "{{ .Env.TURNS_HOST }}", port = {{ $TURNS_PORT }}, transport = "tcp", secret = true, ttl = 86400, algorithm = "turn" }
  {{ end }}
};
{{ end }}

{{ if and $ENABLE_AUTH (eq $AUTH_TYPE "jwt") .Env.JWT_ACCEPTED_ISSUERS -}}
asap_accepted_issuers = { "{{ join "\",\"" (splitList "," .Env.JWT_ACCEPTED_ISSUERS) }}" }
{{ end -}}

{{ if and $ENABLE_AUTH (eq $AUTH_TYPE "jwt") .Env.JWT_ACCEPTED_AUDIENCES -}}
asap_accepted_audiences = { "{{ join "\",\"" (splitList "," .Env.JWT_ACCEPTED_AUDIENCES) }}" }
{{ end -}}

consider_bosh_secure = true;

-- Deprecated in 0.12
-- https://github.com/bjc/prosody/commit/26542811eafd9c708a130272d7b7de77b92712de
{{ $XMPP_CROSS_DOMAINS := $PUBLIC_URL }}
{{ $XMPP_CROSS_DOMAIN := .Env.XMPP_CROSS_DOMAIN | default "" }}
{{ if eq $XMPP_CROSS_DOMAIN "true"}}
cross_domain_websocket = true
cross_domain_bosh = true
{{ else }}
{{ if not (eq $XMPP_CROSS_DOMAIN "false") }}
  {{ $XMPP_CROSS_DOMAINS = list $PUBLIC_URL .Env.XMPP_CROSS_DOMAIN | join "," }}
{{ end }}
cross_domain_websocket = { "{{ join "\",\"" (splitList "," $XMPP_CROSS_DOMAINS) }}" }
cross_domain_bosh = { "{{ join "\",\"" (splitList "," $XMPP_CROSS_DOMAINS) }}" }
{{ end }}

unlimited_jids = {
    "{{ .Env.JICOFO_AUTH_USER }}@{{ .Env.XMPP_AUTH_DOMAIN }}",
    "{{ .Env.JVB_AUTH_USER }}@{{ .Env.XMPP_AUTH_DOMAIN }}"
}

VirtualHost "{{ .Env.XMPP_DOMAIN }}"
{{ if $ENABLE_AUTH }}
  {{ if eq $AUTH_TYPE "jwt" }}
    authentication = "{{ $JWT_AUTH_TYPE }}"
    app_id = "{{ .Env.JWT_APP_ID }}"
    app_secret = "{{ .Env.JWT_APP_SECRET }}"
    allow_empty_token = {{ if $JWT_ALLOW_EMPTY }}true{{ else }}false{{ end }}
    {{ if $JWT_ASAP_KEYSERVER }}
    asap_key_server = "{{ .Env.JWT_ASAP_KEYSERVER }}"
    {{ end }}

    {{ else if eq $AUTH_TYPE "ldap" }}
    authentication = "cyrus"
    cyrus_application_name = "xmpp"
    allow_unencrypted_plain_auth = true
  {{ else if eq $AUTH_TYPE "internal" }}
    authentication = "internal_hashed"
  {{ end }}
{{ else }}
    -- https://github.com/jitsi/docker-jitsi-meet/pull/502#issuecomment-619146339
    {{ if $ENABLE_XMPP_WEBSOCKET }}
    authentication = "token"
    {{ else }}
    authentication = "anonymous"
    {{ end }}
    app_id = ""
    app_secret = ""
    allow_empty_token = true
{{ end }}
    ssl = {
        key = "/config/certs/{{ .Env.XMPP_DOMAIN }}.key";
        certificate = "/config/certs/{{ .Env.XMPP_DOMAIN }}.crt";
    }
    modules_enabled = {
        {{ if $ENABLE_XMPP_WEBSOCKET }}
        "websocket";
        "smacks"; -- XEP-0198: Stream Management
        {{ end }}
        "bosh";
        "pubsub";
        "ping";
        "speakerstats";
        "conference_duration";
        {{ if or .Env.TURN_HOST .Env.TURNS_HOST }}
        "external_services";
        {{ end }}
        "av_moderation";
        {{ if $ENABLE_LOBBY }}
        "muc_lobby_rooms";
        {{ end }}
        {{ if $ENABLE_BREAKOUT_ROOMS }}
        "breakout_rooms";
        {{ end }}
        {{ if .Env.XMPP_MODULES }}
        "{{ join "\";\n\"" (splitList "," .Env.XMPP_MODULES) }}";
        {{ end }}
        {{ if and $ENABLE_AUTH (eq $AUTH_TYPE "ldap") }}
        "auth_cyrus";
        {{end}}
        {{ if .Env.ENABLE_RECORDING }}
        "allow_jibri_tobypass";
        {{ end }}
    }

    {{ if or $ENABLE_LOBBY $ENABLE_BREAKOUT_ROOMS }}
    main_muc = "{{ .Env.XMPP_MUC_DOMAIN }}"
    {{ end }}
    {{ if $ENABLE_LOBBY }}
    lobby_muc = "lobby.{{ .Env.XMPP_DOMAIN }}"
    {{ if .Env.XMPP_RECORDER_DOMAIN }}
    muc_lobby_whitelist = { "{{ .Env.XMPP_RECORDER_DOMAIN }}" }
    {{ end }}
    {{ end }}

    av_moderation_component = "avmoderation.{{ .Env.XMPP_DOMAIN }}"
    speakerstats_component = "speakerstats.{{ .Env.XMPP_DOMAIN }}"
    conference_duration_component = "conferenceduration.{{ .Env.XMPP_DOMAIN }}"

    c2s_require_encryption = false

{{ if $ENABLE_GUEST_DOMAIN }}
VirtualHost "{{ .Env.XMPP_GUEST_DOMAIN }}"
    -- https://github.com/jitsi/docker-jitsi-meet/pull/502#issuecomment-619146339
    {{ if $ENABLE_XMPP_WEBSOCKET }}
    authentication = "token"
    {{ else }}
    authentication = "anonymous"
    {{ end }}
    app_id = ""
    app_secret = ""
    allow_empty_token = true

    c2s_require_encryption = false

{{ end }}

VirtualHost "{{ .Env.XMPP_AUTH_DOMAIN }}"
    ssl = {
        key = "/config/certs/{{ .Env.XMPP_AUTH_DOMAIN }}.key";
        certificate = "/config/certs/{{ .Env.XMPP_AUTH_DOMAIN }}.crt";
    }

    modules_enabled = {
        "limits_exception";
    }

    authentication = "internal_hashed"

{{ if .Env.XMPP_RECORDER_DOMAIN }}
VirtualHost "{{ .Env.XMPP_RECORDER_DOMAIN }}"
    modules_enabled = {
      "ping";
    }
    authentication = "internal_hashed"
{{ end }}

Component "{{ .Env.XMPP_INTERNAL_MUC_DOMAIN }}" "muc"
    storage = "memory"
    modules_enabled = {
        "ping";
        {{ if .Env.XMPP_INTERNAL_MUC_MODULES }}
        "{{ join "\";\n\"" (splitList "," .Env.XMPP_INTERNAL_MUC_MODULES) }}";
        {{ end }}
    }
    restrict_room_creation = true
    muc_room_locking = false
    muc_room_default_public_jids = true

Component "{{ .Env.XMPP_MUC_DOMAIN }}" "muc"
    storage = "memory"
    modules_enabled = {
        "muc_meeting_id";
        {{ if .Env.XMPP_MUC_MODULES -}}
        "{{ join "\";\n\"" (splitList "," .Env.XMPP_MUC_MODULES) }}";
        {{ end -}}
        {{ if and $ENABLE_AUTH (eq $AUTH_TYPE "jwt") -}}
        "{{ join "\";\n\"" (splitList "," .Env.JWT_TOKEN_AUTH_MODULE) }}";
        {{ end -}}
        {{ if .Env.ENABLE_RECORDING -}}
        "allow_jibri_tobypass";
        {{ end -}}
        {{ if eq $ENABLE_SUBDOMAINS "true" -}}
        "muc_domain_mapper";
        {{ end -}}
        {{ if not $DISABLE_POLLS -}}
        "polls";
        {{ end -}}
        {{ if .Env.ENABLE_MEET_STATS -}}
        "meet_stats";
        {{ end -}}
    }
    muc_room_cache_size = 1000
    muc_room_locking = false
    muc_room_default_public_jids = true
    {{ if .Env.ENABLE_MEET_STATS -}}
        meet_stats_host = "{{ .Env.MEET_STATS_HOST }}"
        meet_stats_port = "{{ .Env.MEET_STATS_PORT }}"
        meet_stats_name = "{{ .Env.MEET_STATS_NAME }}"
        meet_stats_user = "{{ .Env.MEET_STATS_USER }}"
        meet_stats_password = "{{ .Env.MEET_STATS_PASSWORD }}"
    {{ end -}}

-- Proxy to jicofo's user JID, so that it doesn't have to register as a component.
Component "{{ .Env.JICOFO_AUTH_USER }}.{{ .Env.XMPP_DOMAIN }}" "client_proxy"
    target_address = "{{ .Env.JICOFO_AUTH_USER }}@{{ .Env.XMPP_AUTH_DOMAIN }}"

Component "speakerstats.{{ .Env.XMPP_DOMAIN }}" "speakerstats_component"
    muc_component = "{{ .Env.XMPP_MUC_DOMAIN }}"

Component "conferenceduration.{{ .Env.XMPP_DOMAIN }}" "conference_duration_component"
    muc_component = "{{ .Env.XMPP_MUC_DOMAIN }}"

Component "avmoderation.{{ .Env.XMPP_DOMAIN }}" "av_moderation_component"
    muc_component = "{{ .Env.XMPP_MUC_DOMAIN }}"

{{ if $ENABLE_LOBBY -}}
Component "lobby.{{ .Env.XMPP_DOMAIN }}" "muc"
    storage = "memory"
    restrict_room_creation = true
    muc_room_locking = false
    muc_room_default_public_jids = true
{{ end -}}