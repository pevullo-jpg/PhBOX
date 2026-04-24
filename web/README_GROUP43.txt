GROUP 43 - Web cache hardening

- removed manifest from source web index
- added no-cache meta headers in web/index.html
- keeps unregister/clear caches bootstrap
- flutter_bootstrap.js now loaded with build version query param
- GitHub workflows stamp build/web/index.html with github.sha
- workflows delete leftover flutter_service_worker.js and manifest.json from build output

Goal: prevent sticky old web releases and restore predictable refresh behavior.
