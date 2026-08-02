# Media Publisher API

Small AWS Lambda/API Gateway backend for the Media Lab mini-program. It exposes
three fixed GET routes and returns redirects to known public sample media:

- `media/sample.mp4`
- `media/sample.m3u8`
- `media/sample.mp3`

The route table is closed and cannot be used as an arbitrary URL proxy. API
Gateway throttles the test deployment to five requests per second with a burst
of ten.

```powershell
npm test
.\deploy.ps1
```
