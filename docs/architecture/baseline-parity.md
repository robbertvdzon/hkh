# Baselinepariteit

De repositories `hkh` en `hkh-autopilot` bevatten bij tag `comparison-baseline-v1` dezelfde
technische baseline. `tools/verify-baseline-parity.py` vergelijkt alle relevante bron-, test-,
build- en configuratiebestanden byte voor byte.

Alleen deze runtime-identiteit verschilt:

| Identiteit | HKH | HKH Autopilot |
|---|---|---|
| repository en images | `hkh` | `hkh-autopilot` |
| OpenShift namespace / ArgoCD-app | `hkh` | `hkh-autopilot` |
| backend application-ID | `hkh` | `hkh-autopilot` |
| Android application-ID | `nl.vdzon.hkh.app` | `nl.vdzon.hkh.autopilot` |
| APK-bestandsnaam | `hkh.apk` | `hkh-autopilot.apk` |
| lokale PostgreSQL-hostpoort | `5434` | `5435` |
| database/PVC/sealed-secret | eigen instantie in namespace `hkh` | eigen instantie in namespace `hkh-autopilot` |

De env-varnamen, modulegrenzen, API-contracten, migraties, dependencyversies, tests, CI-vorm en
containeropbouw blijven gelijk. Na de baseline-tag mogen productfeatures uiteenlopen; de
pariteitscheck is dan historisch bewijs en geen blijvende synchronisatieplicht.
