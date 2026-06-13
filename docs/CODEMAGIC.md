# Codemagic — Parcec (OpenParsec, iOS nativo Swift)

Archivo de workflow: [`codemagic.yaml`](../codemagic.yaml) (raíz del repo).

| Workflow | ID YAML | Cuándo corre |
|----------|---------|--------------|
| iOS → TestFlight | `ios-testflight` | Push a `main` |
| iOS manual | `ios-testflight-manual` | Solo al pulsar Start build |
| IPA ad hoc | `ios-adhoc-manual` | Manual (AltStore / sideload, sin App Store) |

**Bundle ID:** `com.aigch.OpenParsec1`  
**App Store Connect:** ParsecMobile — Apple ID `6780047101`  
**Scheme Xcode:** `OpenParsec`  
**Dependencia:** submódulo `Frameworks/ParsecSDK.framework`

---

## Configuración en Codemagic (copiar tal cual)

### 1. Conectar el repo

1. [codemagic.io](https://codemagic.io) → **Add application**
2. **GitHub** → autoriza → elige tu repo (**Parcec** / OpenParsec)
3. Tipo: **Other** o **iOS** (no Flutter)
4. Rama **main** → **Check for configuration file** → debe aparecer `codemagic.yaml` ✓

### 2. Integración Apple (obligatorio para TestFlight)

**Team settings** → **Team integrations** → **Developer Portal** → **Add key**

| Campo | Valor |
|-------|--------|
| **API key name** | `PARSEC` |
| **Issuer ID** | App Store Connect → Users and Access → Integrations |
| **Key ID** | De la key que creaste |
| **.p8 file** | Descarga única al crear la key |

> El nombre `PARSEC` debe ser **exacto** — está en `codemagic.yaml`.

### 3. Variables de entorno (grupo `parcec`)

En tu app → **Environment variables**:

| Variable | Secret | Valor | Obligatorio |
|----------|--------|-------|-------------|
| `APP_STORE_APPLE_ID` | ✓ | Número Apple ID de la app (App Store Connect → App Information) | No al primer build |

Al crear la variable, **group name:** `parcec` (crear grupo nuevo con ese nombre).

### 4. App Store Connect

1. Usa la app **ParsecMobile** con bundle `com.aigch.OpenParsec1` (Apple ID `6780047101`)
2. App ID en developer.apple.com con capabilities solo las que uses (p. ej. Game Center no hace falta)
3. Anota el **Apple ID numérico** de la app → variable `APP_STORE_APPLE_ID`

### 5. Submódulo ParsecSDK

Codemagic clona con submódulos si el repo está bien configurado. El workflow ejecuta:

```bash
git submodule update --init --recursive
```

Asegúrate de que `.gitmodules` apunta a `Frameworks/ParsecSDK.framework` y que el submódulo está commiteado en GitHub.

### 6. Primer build

**Start new build** → elige el workflow del **YAML**:

- ✅ **iOS → TestFlight (manual)** (`ios-testflight-manual`)
- ❌ **NO** uses **Default Workflow**

Rama: `main`

O desde PowerShell (con API token):

```powershell
# Añade CODEMAGIC_API_TOKEN=... a .local/server.credentials.env
.\scripts\setup-codemagic.ps1
```

---

## Automatización local

```powershell
# En .local/server.credentials.env:
CODEMAGIC_API_TOKEN=tu_token_de_codemagic
# Opcional tras el primer registro:
CODEMAGIC_APP_ID=...
APP_STORE_APPLE_ID=6780047101
```

```powershell
.\scripts\setup-codemagic.ps1
```

El script registra el repo (si falta) y lanza `ios-testflight-manual`.

---

## Validación local (Mac con Xcode)

```bash
git submodule update --init --recursive

xcodebuild analyze \
  -project OpenParsec.xcodeproj \
  -scheme OpenParsec \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
```

Para IPA firmada necesitas certificados locales o usar Codemagic.

---

## Solución de problemas

| Error | Solución |
|-------|----------|
| `integration PARSEC not found` | El nombre en Team integrations debe ser exactamente `PARSEC` |
| `Variable group parcec not found` | Crea al menos una variable en grupo `parcec` |
| `No matching profiles for bundle` | En Team settings → Code signing → Fetch profiles, o deja que el yaml cree perfiles con `fetch-signing-files --create`. Verifica App ID `com.aigch.OpenParsec1` en developer.apple.com |
| `ParsecSDK.framework no encontrado` | `git submodule update --init --recursive` y commit del submódulo |
| `Scheme OpenParsec not found` | Usa workflow YAML, no Default Workflow |
| `APP_STORE_APPLE_ID` vacío | OK en primer build; añádelo después para auto-incrementar build |
| Analyze falla en Windows | Normal: analyze requiere Mac / Xcode |

---

## Checklist Apple Developer

- [ ] App ID `com.aigch.OpenParsec1` creado
- [ ] App en App Store Connect creada (nombre **ParsecMobile**, Apple ID `6780047101`)
- [ ] API Key (.p8) subida a Codemagic como integración **`PARSEC`**
- [ ] Certificados/profiles: Codemagic con `ios_signing.distribution_type: app_store`
- [ ] Icono 1024×1024 en `AppIcon.appiconset` (sin transparencia para App Store)
- [ ] Tras subir IPA: activar TestFlight en ASC (export compliance, beta)
