GRUPPO FUNZIONALE 17

Obiettivo:
- rendere funzionante il login Google per il web con approccio compatibile
- preparare il client ID OAuth web in file dedicato
- mantenere scanner Drive pronto

ATTENZIONE
PRIMA DI TESTARE DEVI INSERIRE IL CLIENT ID WEB QUI:
lib/core/constants/google_oauth_config.dart

E devi configurare in Google Cloud Console:
1. OAuth Client ID di tipo Web application
2. Authorized JavaScript origins con il dominio del sito pubblicato
   Esempio GitHub Pages:
   https://TUOUSERNAME.github.io

Se il repository è servito da sottopercorso, NON mettere il sottopercorso:
giusto: https://TUOUSERNAME.github.io
sbagliato: https://TUOUSERNAME.github.io/NOME-REPO
