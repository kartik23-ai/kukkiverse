import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';
import '../core/constants/api_constants.dart';
import 'liquid_glass.dart';

class SunoCaptchaSheet extends StatefulWidget {
  final String clientCookie;
  final String prompt;
  final String genre;
  final String vocalGender;
  final String vocalExpression;
  final bool isInstrumental;
  final String customLyrics;
  final String taskId;

  const SunoCaptchaSheet({
    super.key,
    required this.clientCookie,
    required this.prompt,
    required this.genre,
    required this.vocalGender,
    required this.vocalExpression,
    required this.isInstrumental,
    required this.customLyrics,
    required this.taskId,
  });

  @override
  State<SunoCaptchaSheet> createState() => _SunoCaptchaSheetState();
}

class _SunoCaptchaSheetState extends State<SunoCaptchaSheet> with SingleTickerProviderStateMixin {
  late final WebViewController _webController;
  final WebviewCookieManager _cookieManager = WebviewCookieManager();
  
  bool _isLoading = true;
  bool _isCaptchaActive = false;
  String _statusText = 'Initializing secure vocal synthesis session...';
  double _statusProgress = 0.1;
  int _redirectCount = 0;
  
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initWebView();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Extracts clerk client value from raw cookie string
  String _extractClientValue(String cookieStr) {
    final parts = cookieStr.split(';');
    for (var p in parts) {
      final trimmed = p.trim();
      if (trimmed.startsWith('__client=')) {
        return trimmed.substring('__client='.length);
      }
    }
    return '';
  }

  void _initWebView() {
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          "Mozilla/5.0 (Linux; Android 13; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
      ..addJavaScriptChannel(
        'RottyChannel',
        onMessageReceived: (JavaScriptMessage msg) {
          try {
            final data = json.decode(msg.message) as Map<String, dynamic>;
            final type = data['type'] ?? '';
            
            if (type == 'generation_triggered') {
              setState(() {
                _statusText = 'Vocal synthesis triggered! Compiling audio waves...';
                _statusProgress = 0.45;
                _isCaptchaActive = false;
              });
            } else if (type == 'prompt_found') {
              setState(() {
                _statusText = 'Entering song composition details...';
                _statusProgress = 0.30;
              });
            } else if (type == 'turnstile_pending') {
              setState(() {
                _statusText = 'Resolving secure gateway authorization...';
                _statusProgress = 0.38;
              });
            } else if (type == 'hcaptcha_visible') {
              if (!_isCaptchaActive) {
                setState(() {
                  _isCaptchaActive = true;
                  _statusText = 'Please complete the hCaptcha images verification to continue!';
                });
              }
            } else if (type == 'hcaptcha_hidden') {
              if (_isCaptchaActive) {
                setState(() {
                  _isCaptchaActive = false;
                  _statusText = 'Verification verified! Resuming song mastering...';
                });
              }
            } else if (type == 'clip_ids_found') {
              final clipIds = data['clips'] as String;
              print("🎯 ROTTY CLIENT WEBVIEW SUCCESS: Captured WebView Clip IDs: $clipIds");
              _submitClipsToBackend(clipIds);
            } else if (type == 'error') {
              final errMsg = data['message'] ?? 'An error occurred';
              _handleFailure(errMsg);
            }
          } catch (e) {
            print("WebView JS message parsing error: $e");
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() {
              _isLoading = true;
              _statusText = 'Connecting to high-fidelity synthesis gateway...';
              _statusProgress = 0.15;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _statusText = 'Gateway connected. Initializing secure vocal session...';
              _statusProgress = 0.25;
            });

            // If we ended up on the home page after authentication, redirect to /create
            final uri = Uri.parse(url);
            if ((uri.path == '/' || uri.path == '') && !url.contains('__clerk_handshake')) {
              if (_redirectCount < 2) {
                _redirectCount++;
                print("🎯 ROTTY CLIENT: Detected home page ($url). Redirecting to /create... (Attempt $_redirectCount)");
                _webController.loadRequest(Uri.parse('https://suno.com/create'));
                return;
              } else {
                print("⚠️ ROTTY CLIENT: Redirect limit exceeded. Clerk cookie might be invalid or expired.");
                _handleFailure("Suno login session has expired. Please copy a new active client cookie key!");
                return;
              }
            }

            // 1. CSS Injection to style Suno site in premium dark mode and hide messy UI elements
            _webController.runJavaScript('''
              (function() {
                var style = document.createElement('style');
                style.innerHTML = `
                  html, body, #__next, .main-layout, main {
                    background-color: #0F0F14 !important;
                    color: #ffffff !important;
                  }
                  /* Hide messy layouts, sidebars, lists, headers and footers */
                  header, footer, nav, aside, 
                  [class*="sidebar"], [class*="Header"], [class*="Footer"], 
                  [class*="logo"], [class*="Logo"], [class*="menu"], 
                  [class*="navigation"], [class*="LeftNav"],
                  [class*="Library"], [class*="Feed"], [class*="Playlists"],
                  [class*="RightNav"], [class*="banner"], [class*="Banner"] {
                    display: none !important;
                  }
                `;
                document.head.appendChild(style);
              })();
            ''');

            // 2. JS Injection to fill form and click Create button
            final clientVal = _extractClientValue(widget.clientCookie);
            final jsInjectCode = _buildJsInjectionCode(clientVal);
            _webController.runJavaScript(jsInjectCode);
          },
        ),
      );

    _startWebViewSession();
  }

  Future<void> _startWebViewSession() async {
    final clientVal = _extractClientValue(widget.clientCookie);
    
    if (clientVal.isNotEmpty) {
      try {
        await _cookieManager.setCookies([
          Cookie('__client', clientVal)
            ..domain = 'suno.com'
            ..path = '/',
          Cookie('__client', clientVal)
            ..domain = '.suno.com'
            ..path = '/',
          Cookie('__client', clientVal)
            ..domain = 'clerk.suno.com'
            ..path = '/',
          Cookie('__client', clientVal)
            ..domain = '.clerk.suno.com'
            ..path = '/',
        ]);
        print("🎯 ROTTY CLIENT: Set cookie __client in WebViewCookieManager successfully!");
        // Crucial delay to let WebView commit cookies to native OS storage before loading URL
        await Future.delayed(const Duration(milliseconds: 800));
      } catch (e) {
        print("⚠️ ROTTY CLIENT: Native cookie injection warning: $e");
      }
    }

    _webController.loadRequest(Uri.parse('https://suno.com/create'));
  }

  String _buildJsInjectionCode(String clientVal) {
    final escapedPrompt = json.encode(widget.prompt);
    final escapedGenre = json.encode(widget.genre);
    final escapedVocal = json.encode("${widget.vocalGender} ${widget.vocalExpression}");
    final escapedCustomLyrics = json.encode(widget.customLyrics);
    
    return '''
      (function() {
        console.log("ROTTY SCRIPT: Running page injection...");
        
        // React/NextJS compatible input value setter
        function setNativeValue(element, value) {
          const valueSetter = Object.getOwnPropertyDescriptor(element, 'value')?.set;
          const prototype = Object.getPrototypeOf(element);
          const prototypeValueSetter = Object.getOwnPropertyDescriptor(prototype, 'value')?.set;
          
          if (prototypeValueSetter && valueSetter !== prototypeValueSetter) {
            prototypeValueSetter.call(element, value);
          } else if (valueSetter) {
            valueSetter.call(element, value);
          } else {
            element.value = value;
          }
          element.dispatchEvent(new Event('input', { bubbles: true }));
        }

        // Intercept window.fetch to capture generation API responses instantly
        if (!window.rottyIntercepted) {
          window.rottyIntercepted = true;
          const originalFetch = window.fetch;
          window.fetch = async function(...args) {
            const response = await originalFetch.apply(this, args);
            const url = args[0];
            if (typeof url === 'string' && (url.includes('/api/generate/v2-web/') || url.includes('/api/generate/'))) {
              try {
                const clone = response.clone();
                const data = await clone.json();
                console.log("ROTTY INTERCEPTED API DATA:", data);
                if (data.clips && data.clips.length > 0) {
                  const clipIds = data.clips.map(c => c.id).join(',');
                  console.log("🎯 ROTTY SCRIPT INTERCEPTED SUCCESS: Captured Clip IDs:", clipIds);
                  if (window.RottyChannel) {
                    window.RottyChannel.postMessage(JSON.stringify({
                      type: 'clip_ids_found',
                      clips: clipIds
                    }));
                  }
                }
              } catch (e) {
                console.error("Error parsing intercepted response:", e);
              }
            }
            return response;
          };
          console.log("ROTTY SCRIPT: window.fetch successfully intercepted!");
        }

        // 1. Force setting document cookie
        if ("$clientVal") {
          document.cookie = "__client=$clientVal; domain=.suno.com; path=/; expires=Fri, 31 Dec 2030 23:59:59 GMT; Secure; SameSite=None";
        }
        
        // 2. SPA client-side home route check to redirect to /create
        setInterval(() => {
          const path = window.location.pathname;
          const href = window.location.href;
          if ((path === '/' || path === '') && !href.includes('__clerk_handshake')) {
            console.log("ROTTY SCRIPT JS REDIRECT: Redirecting client-side to /create...");
            window.location.href = 'https://suno.com/create';
          }
        }, 1000);
        
        let attempts = 0;
        const maxAttempts = 30;
        const interval = setInterval(() => {
          attempts++;
          
          const textareas = document.querySelectorAll('textarea');
          let promptInput = Array.from(textareas).find(t => t.placeholder && (t.placeholder.toLowerCase().includes('prompt') || t.placeholder.toLowerCase().includes('describe') || t.placeholder.toLowerCase().includes('style')));
          if (!promptInput && textareas.length > 0) {
            promptInput = textareas[0];
          }
          
          if (promptInput) {
            clearInterval(interval);
            console.log("ROTTY SCRIPT: Prompt input found! Filling details...");
            if (window.RottyChannel) {
              window.RottyChannel.postMessage(JSON.stringify({type: 'prompt_found'}));
            }
            
            const isCustomMode = ${widget.customLyrics.isNotEmpty};
            let toggleAttempted = false;
            
            if (isCustomMode) {
              const textareasNow = document.querySelectorAll('textarea');
              const hasLyricsInput = Array.from(textareasNow).find(t => t.placeholder && t.placeholder.toLowerCase().includes('lyrics'));
              if (!hasLyricsInput) {
                console.log("ROTTY SCRIPT: Toggling Custom mode...");
                let toggled = false;
                const toggleElements = Array.from(document.querySelectorAll('button, [role="switch"], input[type="checkbox"], label, span, div, p, [class*="toggle" i], [class*="switch" i]'));
                for (const btn of toggleElements) {
                  const text = (btn.textContent || '').trim().toLowerCase();
                  const ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
                  const classOrId = ((btn.className || '') + ' ' + (btn.id || '')).toLowerCase();
                  if (text === 'custom' || text === 'custom mode' || ariaLabel.includes('custom') || classOrId.includes('custom-mode') || classOrId.includes('custommode')) {
                    btn.click();
                    btn.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                    btn.dispatchEvent(new Event('change', { bubbles: true }));
                    if (btn.parentElement) {
                      btn.parentElement.click();
                      btn.parentElement.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                    }
                    toggled = true;
                    console.log("ROTTY SCRIPT: Toggled Custom mode successfully via text/label click!");
                    break;
                  }
                }
                if (!toggled) {
                  const checkboxes = document.querySelectorAll('input[type="checkbox"]');
                  for (const cb of checkboxes) {
                    if (cb.id?.toLowerCase().includes('custom') || cb.name?.toLowerCase().includes('custom')) {
                      cb.click();
                      cb.dispatchEvent(new MouseEvent('click', { bubbles: true }));
                      if (cb.parentElement) {
                        cb.parentElement.click();
                      }
                      toggled = true;
                      console.log("ROTTY SCRIPT: Toggled Custom mode successfully via checkbox click!");
                      break;
                    }
                  }
                }
                toggleAttempted = true;
              } else {
                console.log("ROTTY SCRIPT: Already in Custom Mode!");
              }
            }
            
            setTimeout(() => {
              if (isCustomMode) {
                const textareasAfter = document.querySelectorAll('textarea');
                const lyricsInput = Array.from(textareasAfter).find(t => t.placeholder && t.placeholder.toLowerCase().includes('lyrics')) || textareasAfter[0];
                const styleInput = Array.from(textareasAfter).find(t => t.placeholder && (t.placeholder.toLowerCase().includes('style') || t.placeholder.toLowerCase().includes('genre'))) || textareasAfter[1];
                const titleInput = document.querySelector('input[placeholder*="title" i]') || document.querySelector('input[placeholder*="name" i]') || document.querySelector('input[type="text"]');
                
                if (lyricsInput) setNativeValue(lyricsInput, $escapedCustomLyrics);
                if (styleInput) setNativeValue(styleInput, $escapedGenre + ", " + $escapedVocal);
                if (titleInput) titleInput.value = "Rotty AI Original";
              } else {
                setNativeValue(promptInput, $escapedPrompt + " - Style: " + $escapedGenre + " - Vocals: " + $escapedVocal);
              }
              
              // Wait for Turnstile solver or grace period before clicking Create button!
              let clickAttempts = 0;
              let turnstileDetectedAtLeastOnce = false;
              let turnstileLoadStartTime = Date.now();
              
              const clickInterval = setInterval(() => {
                clickAttempts++;
                const timeElapsed = Date.now() - turnstileLoadStartTime;
                
                const turnstileIframe = document.querySelector('iframe[src*="challenges.cloudflare.com"]');
                const turnstileInput = document.querySelector('input[name="cf-turnstile-response"]');
                const isTurnstileSolved = turnstileInput && turnstileInput.value && turnstileInput.value.length > 0;
                
                const isTurnstilePresent = !!(
                  turnstileIframe || 
                  turnstileInput || 
                  document.querySelector('[class*="cf-turnstile"]') || 
                  document.querySelector('[id*="cf-turnstile"]') || 
                  document.querySelector('[id*="clerk-captcha"]')
                );
                
                if (isTurnstilePresent) {
                  turnstileDetectedAtLeastOnce = true;
                }
                
                // If Turnstile has been detected or we are still within the 4-second grace period:
                if (turnstileDetectedAtLeastOnce || timeElapsed < 4000) {
                  if (turnstileDetectedAtLeastOnce) {
                    if (!isTurnstileSolved) {
                      console.log("ROTTY SCRIPT: Turnstile detected. Waiting for user/auto solve... (Attempt " + clickAttempts + ")");
                      if (window.RottyChannel && clickAttempts % 4 === 1) {
                        window.RottyChannel.postMessage(JSON.stringify({type: 'turnstile_pending'}));
                      }
                      
                      // Only reveal WebView if the Turnstile checkbox widget is visible (width > 100, height > 30) AND remains unsolved for > 3 seconds
                      let isTurnstileVisibleCheckbox = false;
                      if (turnstileIframe) {
                        const rect = turnstileIframe.getBoundingClientRect();
                        isTurnstileVisibleCheckbox = rect.width > 100 && rect.height > 30;
                      }
                      if (isTurnstileVisibleCheckbox && timeElapsed > 3000 && window.RottyChannel) {
                        console.log("ROTTY SCRIPT: Turnstile checkbox visible! Exposing WebView for manual click.");
                        window.RottyChannel.postMessage(JSON.stringify({type: 'hcaptcha_visible'}));
                      }
                      
                      return; // DO NOT CLICK YET, keep waiting
                    } else {
                      console.log("ROTTY SCRIPT: Turnstile solved! Token length: " + turnstileInput.value.length);
                    }
                  } else {
                    // Turnstile not detected yet, but still in the 4-second grace period
                    console.log("ROTTY SCRIPT: Waiting in grace period to see if Turnstile loads... (Elapsed: " + timeElapsed + "ms)");
                    return; // DO NOT CLICK YET, keep waiting
                  }
                }
                
                // If we get here, either Turnstile is solved, or 4 seconds have passed and no Turnstile is present.
                clearInterval(clickInterval);
                const buttons = Array.from(document.querySelectorAll('button'));
                let createBtn = buttons.find(b => {
                  const text = (b.textContent || '').trim().toLowerCase();
                  return text.startsWith('create');
                });
                
                if (createBtn) {
                  console.log("ROTTY SCRIPT: Create button found! Clicking...");
                  if (window.RottyChannel) {
                    window.RottyChannel.postMessage(JSON.stringify({type: 'generation_triggered'}));
                  }
                  createBtn.click();
                  startMonitoringClips();
                } else {
                  console.error("ROTTY SCRIPT: Create button not found!");
                  if (window.RottyChannel) {
                    window.RottyChannel.postMessage(JSON.stringify({type: 'error', message: 'Create button not found'}));
                  }
                }
              }, 500);
              
            }, toggleAttempted ? 1500 : 500);
            
          } else if (attempts >= maxAttempts) {
            clearInterval(interval);
            console.error("ROTTY SCRIPT: Prompt input timeout!");
            if (window.RottyChannel) {
              window.RottyChannel.postMessage(JSON.stringify({type: 'error', message: 'Prompt input timed out. Make sure cookie is valid.'}));
            }
          }
        }, 1000);
        
        // 3. Monitor Captcha and Turnstile status
        let turnstileLoadTime = Date.now();
        setInterval(() => {
          // Auto-dismiss cookies/consent banners to prevent blocking UI
          try {
            const cookieButtons = Array.from(document.querySelectorAll('button'));
            for (const btn of cookieButtons) {
              const text = (btn.textContent || '').trim().toLowerCase();
              if (text === 'accept' || text === 'accept all' || text === 'accept cookies' || text === 'allow cookies' || text === 'agree' || text === 'got it') {
                console.log("ROTTY SCRIPT: Auto-clicking cookie consent button: " + text);
                btn.click();
              }
            }
            const banners = document.querySelectorAll('[class*="cookie" i], [id*="cookie" i], [class*="consent" i], [id*="consent" i], [class*="banner" i]');
            banners.forEach(b => {
              if (b.tagName === 'DIV' || b.tagName === 'SECTION') {
                b.style.display = 'none';
              }
            });
          } catch (e) {
            console.error("ROTTY SCRIPT: Cookies dismissal error:", e);
          }

          // Check hCaptcha popup
          const captchaIframe = document.querySelector('iframe[src*="hcaptcha.com"][title*="challenge" i]');
          let isCaptchaVisible = false;
          if (captchaIframe) {
            const rect = captchaIframe.getBoundingClientRect();
            isCaptchaVisible = rect.width > 100 && rect.height > 100;
          }
          
          // Check Cloudflare Turnstile
          const turnstileIframe = document.querySelector('iframe[src*="challenges.cloudflare.com"]');
          const turnstileInput = document.querySelector('input[name="cf-turnstile-response"]');
          const isTurnstileSolved = turnstileInput && turnstileInput.value && turnstileInput.value.length > 0;
          
          const isTurnstilePresent = !!(
            turnstileIframe || 
            turnstileInput || 
            document.querySelector('[class*="cf-turnstile"]') || 
            document.querySelector('[id*="cf-turnstile"]') || 
            document.querySelector('[id*="clerk-captcha"]')
          );
          
          let isTurnstileVisibleCheckbox = false;
          if (turnstileIframe) {
            const rect = turnstileIframe.getBoundingClientRect();
            isTurnstileVisibleCheckbox = rect.width > 100 && rect.height > 30;
          }
          
          let isTurnstilePendingUser = false;
          if (isTurnstilePresent && isTurnstileVisibleCheckbox && !isTurnstileSolved) {
            // Show WebView only if Turnstile needs verification for > 3 seconds
            if (Date.now() - turnstileLoadTime > 3000) {
              isTurnstilePendingUser = true;
            }
          }
          
          const anyActive = isCaptchaVisible || isTurnstilePendingUser;
          if (window.RottyChannel) {
            window.RottyChannel.postMessage(JSON.stringify({
              type: anyActive ? 'hcaptcha_visible' : 'hcaptcha_hidden'
            }));
          }
        }, 1000);
        
        // 4. Monitor page for generated song clip links (Fallback)
        function startMonitoringClips() {
          // Capture existing song IDs on the page to prevent matching previously generated tracks!
          const existingIds = new Set();
          Array.from(document.querySelectorAll('a[href*="/song/"]')).forEach(l => {
            const parts = l.href.split('/song/');
            if (parts.length > 1) {
              const id = parts[1].split('?')[0].split('/')[0];
              if (id && id.length > 10) existingIds.add(id);
            }
          });
          console.log("ROTTY SCRIPT: Existing song IDs captured:", Array.from(existingIds));

          let checkCount = 0;
          const clipInterval = setInterval(() => {
            checkCount++;
            const songLinks = Array.from(document.querySelectorAll('a[href*="/song/"]'));
            if (songLinks.length > 0) {
              const newIds = [];
              songLinks.forEach(l => {
                const parts = l.href.split('/song/');
                if (parts.length > 1) {
                  const id = parts[1].split('?')[0].split('/')[0];
                  if (id && id.length > 10 && !existingIds.has(id)) {
                    newIds.push(id);
                  }
                }
              });
              
              if (newIds.length >= 2) {
                clearInterval(clipInterval);
                const uniqueNewIds = Array.from(new Set(newIds)).slice(0, 2);
                console.log("ROTTY SCRIPT: Extracted NEW Clip IDs:", uniqueNewIds);
                if (window.RottyChannel) {
                  window.RottyChannel.postMessage(JSON.stringify({
                    type: 'clip_ids_found',
                    clips: uniqueNewIds.join(',')
                  }));
                }
              }
            }
            
            if (checkCount > 40) {
              clearInterval(clipInterval);
              console.error("ROTTY SCRIPT: Clip monitoring timed out.");
              if (window.RottyChannel) {
                window.RottyChannel.postMessage(JSON.stringify({type: 'error', message: 'Clip generation timed out.'}));
              }
            }
          }, 3000);
        }
      })();
    ''';
  }

  Future<void> _submitClipsToBackend(String clipIds) async {
    setState(() {
      _statusText = 'Synergizing clips with backend proxy server...';
      _statusProgress = 0.85;
    });

    try {
      final payload = json.encode({
        'taskId': widget.taskId,
        'clipIds': clipIds,
        'clientCookie': widget.clientCookie,
        'prompt': widget.prompt,
        'genre': widget.genre,
      });

      // Encrypt and post to backend proxy
      // As backend supports unencrypted raw JSON for dev as well, we use unencrypted for dev mode
      final res = await http.post(
        Uri.parse('${ApiConstants.backendUrl}/api/track-webview-clips'),
        headers: {'Content-Type': 'application/json'},
        body: payload,
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop('success');
        }
      } else {
        throw Exception("Server returned code: ${res.statusCode}");
      }
    } catch (e) {
      _handleFailure("Backend handshaking failed: $e");
    }
  }

  void _handleFailure(String error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verification trigger failed: $error'), backgroundColor: Colors.red),
      );
      Navigator.of(context).pop('error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F14),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Column(
        children: [
          // Elegant Header Drag Handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Premium Studio Status Panel
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop('backup'),
                  child: Text(
                    'Cancel composition',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'ROTTY Shield v2.0',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 120),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Interactive WebView Viewport
          Expanded(
            child: Stack(
              children: [
                // Hidden webview behind our premium loader overlay
                WebViewWidget(controller: _webController),
                
                // Loading Overlay Layer (fades out when WebView is loaded, keeping user strictly focused on verification)
                if (_isLoading || !_isCaptchaActive)
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFF0F0F14),
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: LiquidGlass(
                          borderRadius: 24,
                          surfaceOpacity: 0.03,
                          borderOpacity: 0.1,
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Pulsing Equalizer Logo
                              ScaleTransition(
                                scale: Tween<double>(begin: 0.95, end: 1.05).animate(
                                  CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
                                ),
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFF007A), Color(0xFF7A00FF)],
                                    ),
                                    borderRadius: BorderRadius.circular(40),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFFF007A).withOpacity(0.3),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      )
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.auto_awesome_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              // Status message
                              Text(
                                _statusText,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              
                              // Minimal progress bar
                              Container(
                                width: 200,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: _statusProgress,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFF007A), Color(0xFF7A00FF)],
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '${(_statusProgress * 100).toInt()}% arranged',
                                style: GoogleFonts.inter(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                // Minimal overlay banner when WebView is active to guide user
                if (_isCaptchaActive)
                  Positioned(
                    top: 16,
                    left: 24,
                    right: 24,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFF007A).withOpacity(0.3)),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          )
                        ]
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security_rounded, color: Color(0xFFFF007A), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please complete the verification check below to finish your premium composition!',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
