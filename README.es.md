# discourse-peertube-embed

[English](README.md) · **Español**

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
- **Clic para reproducir**: solo se carga la miniatura hasta que el usuario hace clic, así PeerTube no recibe visitas de quien no reproduce.
- **Enlaces con tiempo de inicio**: `?start=1m30s`, `?t=90` y `#t=90` arrancan la reproducción en ese momento.
- **Insignia de vivo**: `● En vivo · N espectadores`, `En vivo pronto` o `Transmisión finalizada`, actualizada en segundo plano.
- **Modo cine**: agranda el reproductor sin recargarlo (Esc para salir).
- **Botón en el editor**: pegás una URL de PeerTube, se valida contra las instancias permitidas y se inserta en su propia línea.
- **Miniaturas en la lista de temas** para los temas con un video de PeerTube, con ▶ o EN VIVO superpuesto.
- **Galería `/videos`** con filtros Todos / En vivo / categoría y un enlace en la barra lateral. Los videos se indexan solos al procesar los posts; no hace falta ninguna etiqueta. Respeta los permisos de categorías y omite susurros y posts ocultos.
- **Eventos**: las instancias PeerTube se agregan a los hosts permitidos de transmisiones del plugin de eventos, así la URL de transmisión de un evento puede ser un vivo de PeerTube y se muestra en la tarjeta del evento junto al chat.
- Emails, RSS y buscadores reciben una miniatura con enlace y el título.

## Instalación

Seguí [Install plugins in Discourse](https://meta.discourse.org/t/install-plugins-in-discourse/19157) usando:

```
https://github.com/somos-criptonautas/discourse-peertube-embed.git
```

Requiere un Discourse reciente (2026.9 o posterior).

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
| `peertube_embed_live_refresh_seconds` | 60 | Intervalo de actualización del vivo (mín. 60). |
| `peertube_embed_sync_event_livestream_hosts` | true | Agrega las instancias a los hosts permitidos de transmisiones de eventos. |

Después de agregar una instancia, volvé a procesar los posts que ya la enlazan para que tengan el nuevo onebox y queden indexados:

```
./launcher enter app
rake posts:rebake_match["tube.example.org"]
```

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

## Licencia

[MIT](LICENSE) © 2026 Criptonautas
