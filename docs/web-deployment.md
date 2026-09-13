# Web App Deployment Guide

The Tuner app can run as a web application, allowing users to access it from any modern browser.

## Important: Audio Recording on Web

⚠️ **Audio recording functionality has limitations on web:**

| Feature | Status | Notes |
|---------|--------|-------|
| **UI Display** | ✅ Full | All visual components work perfectly |
| **Microphone Access** | ⚠️ Limited | Requires HTTPS, user permission, browser support |
| **Pitch Detection** | ⚠️ Limited | Depends on browser and microphone permissions |
| **Note Display** | ✅ Full | Works without microphone |
| **Gauge Visualization** | ✅ Full | Works without microphone |

### Why Audio is Limited on Web

1. **Browser Sandbox**: Web browsers restrict microphone access for security
2. **HTTPS Required**: Microphone access only works on secure (HTTPS) connections
3. **User Permission**: Users must explicitly grant microphone access
4. **Browser Compatibility**: Not all browsers support Web Audio API equally
5. **Package Support**: The `record` package has limited web implementation

### Web Audio Workarounds

If you want full audio support on web, consider:
1. Using a different audio library with better web support (Web Audio API wrapper)
2. Building a separate web-specific interface that uses browser audio APIs directly
3. Focusing the web version on note reference/learning (no live recording)

## Quick Start: Deploy to Web

### Option A: GitHub Pages (Automatic)

1. Enable GitHub Pages in repo settings
   - Go to Settings → Pages
   - Source: Deploy from a branch
   - Branch: `gh-pages`

2. The "Build Web App" workflow automatically deploys to GitHub Pages when:
   - You push a tag (v1.0.0)
   - You push to main branch (if uncommented in workflow)

3. Access at: `https://plangora.github.io/tuner/`

### Option B: Custom Domain

To deploy to a custom domain (e.g., tuner.plangora.dev):

1. Edit `.github/workflows/build-web.yml` and uncomment:
   ```yaml
   cname: tuner.plangora.dev
   ```

2. Set up DNS for your domain:
   ```
   CNAME record: tuner.plangora.dev → plangora.github.io
   ```

3. Enable custom domain in repo settings (Pages → Custom domain)

4. Push a tag to trigger deployment

### Option C: Manual Deployment

Download the web build from GitHub Actions and host anywhere:

1. Download `web-build` artifact from Actions
2. Upload `build/web/` directory to your web server
3. Configure web server (examples below)

## Hosting Options

### GitHub Pages (Free)
- ✅ Free hosting
- ✅ HTTPS included
- ✅ Automatic deployments
- ❌ Limited to `username.github.io` or custom domain
- ✅ Great for demos and portfolios

### Netlify (Free tier)
- ✅ Free hosting with generous limits
- ✅ HTTPS included
- ✅ Easy deployment via drag-and-drop or Git
- ✅ Custom domain support
- ✅ Analytics included

Deployment:
```bash
# Install Netlify CLI
npm install -g netlify-cli

# Deploy
netlify deploy --prod --dir=build/web
```

### Vercel (Free tier)
- ✅ Free hosting
- ✅ HTTPS included
- ✅ Easy Git integration
- ✅ Fast global CDN
- ✅ Analytics included

Deployment:
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel --prod
```

### AWS S3 + CloudFront
- ✅ Cheap for low traffic
- ✅ Highly scalable
- ⚠️ More setup required
- ✅ Custom domain support

```bash
# Deploy to S3
aws s3 sync build/web s3://tuner-bucket --delete

# CloudFront automatically caches and serves
```

### Firebase Hosting
- ✅ Free tier with generous limits
- ✅ HTTPS included
- ✅ Easy deployment
- ✅ Analytics included
- ✅ Custom domain support

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Deploy
firebase deploy
```

## Building Locally

To test the web build locally:

```bash
# Build for web
flutter build web --release

# Start a local server
cd build/web
python3 -m http.server 8000

# Open browser to http://localhost:8000
```

## Optimizing for Web

### Reduce Download Size

The web build is currently ~39MB. To optimize:

1. **Use HTML renderer** (default, faster):
   ```bash
   flutter build web --release --web-renderer=html
   ```

2. **Enable tree-shaking** (already enabled by default):
   - Removes unused icon fonts and assets
   - Can save several MB

3. **Use compression** on web server:
   - Enable gzip compression
   - Most hosting platforms do this automatically

### Performance Tips

1. **Use CanvasKit only if needed** for custom painting
   - CanvasKit is larger but renders graphics better
   - For this app, HTML renderer is sufficient

2. **Enable service worker** for offline access:
   - Flutter web includes a service worker by default
   - Apps work offline after first load

3. **Use a CDN** to serve from multiple locations:
   - Netlify, Vercel, GitHub Pages all use CDNs
   - Reduces latency globally

## Testing Audio on Web

To test microphone functionality on web:

1. **Run locally with HTTPS** (required for microphone):
   ```bash
   # Using Flutter's built-in server (HTTP only - no mic access)
   flutter run -d chrome

   # Alternative: Use local HTTPS (requires setup)
   # This is optional for development
   ```

2. **Test on deployed site** (HTTPS enabled):
   - Deploy to GitHub Pages, Netlify, or Vercel
   - Open in Chrome/Firefox/Safari
   - Browser will prompt for microphone permission
   - Pitch detection may work depending on browser and package support

## Browser Compatibility

| Browser | Support | Notes |
|---------|---------|-------|
| Chrome | ✅ Full | Best support for Web Audio API |
| Firefox | ✅ Full | Good support |
| Safari | ✅ Good | Works but microphone may be limited |
| Edge | ✅ Full | Chromium-based, same as Chrome |
| Mobile Chrome | ⚠️ Limited | Microphone works, but UI may need responsive design |
| Mobile Safari | ⚠️ Limited | Similar to desktop Safari |
| IE 11 | ❌ No | Not supported (use Edge instead) |

## Security Considerations

### HTTPS Required
Microphone access only works on HTTPS connections. HTTP connections cannot access the microphone for security reasons.

### User Privacy
- Users must explicitly grant microphone permission
- Browser shows a permission prompt
- No audio is recorded without explicit user action
- No data is sent to servers (all processing is local in the browser)

### Content Security Policy
The web app includes a Content Security Policy (CSP) header that:
- Prevents inline script execution
- Restricts external resource loading
- Protects against XSS attacks

## Monitoring Web Traffic

### GitHub Pages Analytics
- No built-in analytics
- Consider adding Google Analytics or Plausible

### Third-party Analytics

Add to `web/index.html`:

```html
<!-- Google Analytics -->
<script async src="https://www.googletagmanager.com/gtag/js?id=GA_MEASUREMENT_ID"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'GA_MEASUREMENT_ID');
</script>
```

## Troubleshooting

### "Microphone not working on web"
- ✅ Verify site is HTTPS (required for microphone)
- ✅ Check browser console for permission errors
- ✅ Make sure browser microphone permissions are enabled
- ✅ Try a different browser (Chrome has best support)

### "Web app is slow"
- ✅ Check network tab in browser DevTools
- ✅ Verify hosting provider has good latency in your region
- ✅ Consider using a CDN (all recommended hosts do this)
- ✅ Clear browser cache (Ctrl+Shift+Delete)

### "App looks wrong on mobile"
- The UI is built for desktop screens
- Consider adding responsive breakpoints to widgets
- Use `MediaQuery.of(context).size` to detect screen size
- Optimize layout for touch/mobile devices

## Future: Progressive Web App (PWA)

To make the web app installable like a native app:

1. Update `web/manifest.json` with app metadata
2. Add PWA icons
3. Service worker already included by Flutter
4. Users can "Install" on home screen

No additional code needed — Flutter handles this automatically!

## References

- [Flutter Web Deployment](https://flutter.dev/docs/deployment/web)
- [GitHub Pages Hosting](https://pages.github.com/)
- [Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [Progressive Web Apps](https://web.dev/progressive-web-apps/)
