# discourse-peertube-embed

[English](README.md) · **Español**

> **Estado: experimental (0.1.0).** Se puede usar, pero puede cambiar entre versiones; mirá [Limitaciones conocidas](#limitaciones-conocidas).

Soporte nativo de PeerTube para Discourse: los videos, transmisiones en vivo y listas de tus instancias PeerTube se convierten en reproductores que cargan al hacer clic, con insignia de vivo, una galería `/videos`, miniaturas en la lista de temas y soporte para transmisiones de eventos.

```
┌──────────────────────────────────────────────┐
│ ● EN VIVO  👁 128                            │
│                                              │
│                    ( ▶ )                     │
│                                       24:13  │
├──────────────────────────────────────────────┤
│ Análisis semanal de BTC #42              ⛶   │
│ Criptonautas · tube.example.org              │
└──────────────────────────────────────────────┘
```

## Funciones

- **Onebox del lado del servidor** para las instancias permitidas, armado con la API pública de PeerTube: `/w/<id>`, `/videos/watch/<id>`, `/videos/embed/<id>` y listas (`/w/p/<id>`, …). No hace falta configurar `allowed_iframes`.
- **Clic para reproducir**: el reproductor de PeerTube carga solo cuando el usuario hace clic. Las miniaturas las sirve tu foro cuando `download remote images to local` está activado (lo predeterminado en Discourse); si no, se cargan desde la instancia.
- **Enlaces con tiempo de inicio**: `?start=1m30s`, `?t=90` y `#t=90` arrancan la reproducción en ese momento.
- **Insignia de vivo**: `● En vivo · N espectadores`, `En vivo pronto` o `Transmisión finalizada`, actualizada en segundo plano.
- **Modo cine**: agranda el reproductor sin recargarlo (Esc para salir).
- **Botón en el editor**: subí un video a PeerTube (solo grupos permitidos) o pegá una URL de PeerTube.
  - Las subidas van a la instancia principal con una cuenta de servicio, en partes de 5 MB a través del foro (las credenciales nunca llegan al navegador; incluye progreso, reintentos y cancelación).
  - Canal: por categoría (`slug-de-categoría:canal`), o el canal por defecto.
  - La privacidad sigue a la categoría: categorías públicas → Pública, categorías restringidas → No listada.
- **Miniaturas en la lista de temas** para los temas con un video de PeerTube, con ▶ o EN VIVO superpuesto.
- **Galería `/videos`** con un selector de origen (Todo / Comunidad / Instancia) y un enlace en la barra lateral:
  - **Todo**: videos de la comunidad y de la instancia mezclados por fecha, cada uno con una insignia de origen.
  - **Comunidad**: videos publicados en el foro, con filtros En vivo y categoría. Se indexan solos al procesar los posts; respeta los permisos de categorías y omite susurros y posts ocultos.
  - **Instancia**: los videos locales de la instancia PeerTube principal, como la portada de PeerTube: Lo último, Tendencia, Al azar y En vivo, más un selector de canal que filtra la página (`?channel=`).
- **Los videos de la instancia se reproducen en un modal** dentro del foro, con enlace al tema si el video ya se publicó, o un botón **Comentar en el foro** que abre el editor con el enlace y el título del video.
- **Eventos**: las instancias PeerTube se agregan a los hosts permitidos de transmisiones del plugin de eventos, así la URL de transmisión de un evento puede ser un vivo de PeerTube y se muestra en la tarjeta del evento junto al chat.
- Emails, RSS y buscadores reciben una miniatura con enlace y el título.

## Instalación

Seguí [Install plugins in Discourse](https://meta.discourse.org/t/install-plugins-in-discourse/19157) usando:

```
https://github.com/somos-criptonautas/discourse-peertube-embed.git
```

Requiere Discourse 2026.9 o posterior (usa las rutas actuales de módulos del frontend). El CI corre contra Discourse `main`; las versiones anteriores no se prueban.

## Ajustes

| Ajuste | Por defecto | |
|---|---|---|
| `peertube_embed_enabled` | false | Activa el plugin. |
| `peertube_embed_instances` | — | Dominios de las instancias, p. ej. `tube.example.org`. |
| `peertube_embed_click_to_play` | true | Primero la miniatura, el reproductor al hacer clic. |
| `peertube_embed_theater_mode` | true | Botón de modo cine. |
| `peertube_embed_composer_button` | true | Botón en la barra del editor. |
| `peertube_embed_topic_list_thumbnails` | true | Miniaturas en la lista de temas. |
| `peertube_embed_videos_page` | true | Galería `/videos` y enlace en la barra lateral. |
| `peertube_embed_home_instance` | — | Instancia que se muestra en la pestaña Instancia (por defecto, la primera permitida). |
| `peertube_embed_videos_default_tab` | all | Pestaña que abre primero: `all`, `community` o `instance`. |
| `peertube_embed_live_refresh_seconds` | 60 | Intervalo de actualización del vivo (mín. 60). |
| `peertube_embed_sync_event_livestream_hosts` | true | Agrega las instancias a los hosts permitidos de transmisiones de eventos. |
| `peertube_embed_upload_enabled` | false | Subidas a PeerTube desde el editor. |
| `peertube_embed_upload_username` / `_password` | — | Cuenta de servicio de PeerTube (la contraseña es un ajuste secreto). |
| `peertube_embed_upload_channel` | — | Canal por defecto para las subidas. |
| `peertube_embed_upload_category_channels` | — | Pares opcionales `slug-de-categoría:canal`. |
| `peertube_embed_upload_allowed_groups` | admins, moderadores, NC2 | Quién puede subir. |
| `peertube_embed_upload_max_size_mb` | 0 | Límite en MB; 0 = sin límite (deciden la cuota y los límites de PeerTube). |

Después de agregar una instancia, volvé a procesar los posts que ya la enlazan para que tengan el nuevo onebox y queden indexados:

```
./launcher enter app
rake posts:rebake_match["tube.example.org"]
```

## Datos y acceso a la red

- **Servidor → PeerTube**: cuando se procesa un post con un enlace de PeerTube, el servidor pide `/api/v1/videos/<id>` (o `/api/v1/video-playlists/<id>`) a esa instancia. Una tarea programada (cada minuto) revisa los videos en vivo publicados en los últimos 90 días, hasta 30 por vez. Solo se contactan instancias permitidas, con el cliente HTTP de Discourse protegido contra SSRF y sus tiempos de espera habituales. No se envían datos de usuarios. La pestaña Instancia y las páginas de canales listan los videos y canales locales de la instancia principal a través del servidor, con caché de 5 minutos (videos) y 1 hora (canales), así los visitantes no contactan la instancia hasta que dan play.
- **Subidas**: los archivos de video pasan por el servidor del foro hacia la instancia principal con la cuenta de servicio; el token de acceso se guarda en Redis hasta que vence.
- **Navegador → PeerTube**: el iframe del reproductor después del clic (o enseguida si el clic para reproducir está desactivado), y las miniaturas si no se descargan localmente.
- **Base de datos**: una tabla, `peertube_videos` (una fila por video y post: título, URL de miniatura, duración, estado del vivo). Se incluye en los backups.

## Desactivar y desinstalar

- Desactivar `peertube_embed_enabled` detiene los onebox, la indexación, la tarea de vivos, `/videos` y los endpoints JSON. Los posts ya procesados conservan una tarjeta estática con enlace a PeerTube hasta que se vuelvan a procesar.
- Al desinstalar el plugin, la tabla `peertube_videos` queda en la base. Para borrarla, eliminala a mano después de desinstalar.

## Solución de problemas

- **El enlace queda como enlace simple**: revisá que el dominio esté en `peertube_embed_instances`, que el servidor llegue a la API de la instancia, y volvé a procesar el post.
- **`/videos` está vacío**: los posts escritos antes de activar el plugin necesitan un rebake.
- **No aparece la insignia de vivo**: la tarea actualiza cada minuto; aparece cuando la instancia informa el estado del vivo.

## Limitaciones conocidas

- La tarjeta de transmisión del evento tiene un clic para reproducir simple (sin insignia de vivo ni modo cine).
- Emails y RSS muestran una miniatura y el título estáticos.
- El CI solo prueba Discourse `main`; todavía no hay pruebas de navegador del reproductor ni de la galería.

## Transmisiones en vivo con PeerTube

- Transmití desde OBS o ffmpeg al endpoint RTMP de la instancia.
- Usá un **vivo permanente/recurrente** para eventos periódicos: la URL y la clave no cambian, y cada sesión puede guardarse como repetición.
- La latencia ronda los 30–40 s con P2P y los 10–15 s con el modo "latencia reducida" (sin P2P).
- Las sesiones interactivas pueden hacerse en una sala de Discourse Voice (LiveKit) y emitirse a PeerTube, capturando la sala con OBS o con LiveKit Egress (room composite → RTMP).

## Desarrollo

```
pnpm install
pnpm lint
bundle exec rubocop
```

Los specs corren dentro de un checkout de Discourse: `LOAD_PLUGINS=1 bin/rspec plugins/discourse-peertube-embed/spec`.

## Soporte

Abrí un issue en <https://github.com/somos-criptonautas/discourse-peertube-embed/issues>.

## Licencia

[MIT](LICENSE) © 2026 Criptonautas
