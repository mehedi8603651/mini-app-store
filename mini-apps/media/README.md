# Media Lab

Android-focused playback sample for the mini-program platform. It exercises:

- progressive MP4 video;
- adaptive HLS/M3U8 video;
- headless foreground MP3 audio;
- native controls and fullscreen video;
- host-approved temporary audio/video caching;
- volume, speed, seek, lifecycle status, and playback callbacks.

The mini-program declares only fixed relative Publisher API routes. The test
backend redirects those routes to the public samples from `preview.html` while
keeping arbitrary URLs out of the static JSON and live state.

```powershell
miniprogram build
miniprogram artifact build
miniprogram artifact verify
```
