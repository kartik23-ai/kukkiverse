// ═══════════════════════════════════════════════════════════
// ROTTY MUSIC — WEBSITE ENGINE v1.0.1 (GOLD RELEASE)
// Three.js morphing icosahedron + Sandbox Audio Simulation + GSAP
// ═══════════════════════════════════════════════════════════

// --- Three.js Setup ---
const canvas = document.getElementById('bg-canvas');
const scene = new THREE.Scene();
scene.fog = new THREE.FogExp2(0x020204, 0.025);

const camera = new THREE.PerspectiveCamera(55, window.innerWidth / window.innerHeight, 0.1, 1000);
const renderer = new THREE.WebGLRenderer({
    canvas, alpha: true, antialias: true, powerPreference: "high-performance"
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
camera.position.z = 18;

// --- Main 3D Object: Morphing icosahedron mesh ---
const icoGeo = new THREE.IcosahedronGeometry(4.5, 4);
const originalPositions = icoGeo.attributes.position.array.slice();

// Physical glass-like neon material
const icoMat = new THREE.MeshPhysicalMaterial({
    color: 0xFF5F38,
    emissive: 0x150505,
    roughness: 0.18,
    metalness: 0.8,
    clearcoat: 1.0,
    clearcoatRoughness: 0.08,
    transmission: 0.25,
    thickness: 1.2,
    wireframe: false,
});

const icoMesh = new THREE.Mesh(icoGeo, icoMat);
scene.add(icoMesh);

// Wireframe scanner overlay
const wireGeo = new THREE.IcosahedronGeometry(4.55, 4);
const wireMat = new THREE.MeshBasicMaterial({
    color: 0x8A2BE2,
    wireframe: true,
    transparent: true,
    opacity: 0.08,
});
const wireMesh = new THREE.Mesh(wireGeo, wireMat);
scene.add(wireMesh);

// --- Star Field Floating Particles ---
const particlesCount = 700;
const particlesGeo = new THREE.BufferGeometry();
const particlesPos = new Float32Array(particlesCount * 3);
for (let i = 0; i < particlesCount; i++) {
    particlesPos[i * 3] = (Math.random() - 0.5) * 75;
    particlesPos[i * 3 + 1] = (Math.random() - 0.5) * 75;
    particlesPos[i * 3 + 2] = (Math.random() - 0.5) * 75;
}
particlesGeo.setAttribute('position', new THREE.BufferAttribute(particlesPos, 3));
const particlesMat = new THREE.PointsMaterial({
    color: 0x00F0FF,
    size: 0.07,
    transparent: true,
    opacity: 0.45,
    sizeAttenuation: true,
});
const particles = new THREE.Points(particlesGeo, particlesMat);
scene.add(particles);

// --- Lighting ---
scene.add(new THREE.AmbientLight(0xffffff, 0.35));

const lightRed = new THREE.DirectionalLight(0xFF5F38, 4);
lightRed.position.set(10, 8, 5);
scene.add(lightRed);

const lightPurple = new THREE.DirectionalLight(0x8A2BE2, 4);
lightPurple.position.set(-10, -8, 5);
scene.add(lightPurple);

const lightBlue = new THREE.PointLight(0x00F0FF, 6, 60);
lightBlue.position.set(0, 5, -8);
scene.add(lightBlue);

// --- Mouse Tracking & Custom Coordinates ---
let mouseX = 0, mouseY = 0;
const cursorGlow = document.getElementById('cursorGlow');

document.addEventListener('mousemove', (e) => {
    mouseX = (e.clientX - window.innerWidth / 2) * 0.0035;
    mouseY = (e.clientY - window.innerHeight / 2) * 0.0035;
    if (cursorGlow) {
        cursorGlow.style.left = e.clientX + 'px';
        cursorGlow.style.top = e.clientY + 'px';
    }
});

document.addEventListener('touchmove', (e) => {
    if (e.touches.length > 0) {
        mouseX = (e.touches[0].clientX - window.innerWidth / 2) * 0.003;
        mouseY = (e.touches[0].clientY - window.innerHeight / 2) * 0.003;
    }
}, { passive: true });

// --- Scroll Progress Management ---
let scrollProgress = 0;
window.addEventListener('scroll', () => {
    const maxScroll = document.body.scrollHeight - window.innerHeight;
    scrollProgress = maxScroll > 0 ? Math.max(0, Math.min(1, window.scrollY / maxScroll)) : 0;

    const nav = document.getElementById('navbar');
    if (nav) nav.classList.toggle('scrolled', window.scrollY > 60);
});

// --- Dynamic Color Control from Sandbox ---
let targetIcoColor = new THREE.Color(0xFF5F38); // Coral default
let targetWireColor = new THREE.Color(0x8A2BE2); // Purple default

// --- 3D Vertex Distortion Morphing ---
function morphVertices(time) {
    if (!icoMesh || !icoMesh.geometry) return;
    const geom = icoMesh.geometry;
    const posAttr = geom.attributes.position;
    if (!posAttr || posAttr.count > 300) return; // Skip complex shapes to ensure 60 FPS mobile performance!
    
    const pos = posAttr.array;
    if (!geom.userData.originalPositions) {
        geom.userData.originalPositions = pos.slice();
    }
    const orig = geom.userData.originalPositions;
    
    // Apply dynamic vertex noise deformation
    for (let i = 0; i < pos.length; i += 3) {
        if (i >= orig.length) break;
        const ox = orig[i];
        const oy = orig[i + 1];
        const oz = orig[i + 2];
        
        const noise = Math.sin(time * 1.5 + ox * 0.8) *
                      Math.cos(time * 1.2 + oy * 0.6) *
                      Math.sin(time * 0.9 + oz * 0.4) * 0.22;
                      
        const scale = 1 + noise * (0.08 + scrollProgress * 0.15);
        pos[i] = ox * scale;
        pos[i + 1] = oy * scale;
        pos[i + 2] = oz * scale;
    }
    posAttr.needsUpdate = true;
    
    // Wireframe distortion
    if (wireMesh && wireMesh.geometry) {
        const wGeom = wireMesh.geometry;
        const wPosAttr = wGeom.attributes.position;
        if (wPosAttr) {
            const wPos = wPosAttr.array;
            if (!wGeom.userData.originalPositions) {
                wGeom.userData.originalPositions = wPos.slice();
            }
            const wOrig = wGeom.userData.originalPositions;
            for (let i = 0; i < wPos.length; i += 3) {
                if (i >= wOrig.length) break;
                const ox = wOrig[i];
                const oy = wOrig[i + 1];
                const oz = wOrig[i + 2];
                const noise = Math.sin(time * 1.5 + ox * 0.8) *
                              Math.cos(time * 1.2 + oy * 0.6) *
                              Math.sin(time * 0.9 + oz * 0.4) * 0.22;
                const scale = 1.012 + noise * (0.08 + scrollProgress * 0.15);
                wPos[i] = ox * scale;
                wPos[i + 1] = oy * scale;
                wPos[i + 2] = oz * scale;
            }
            wPosAttr.needsUpdate = true;
        }
    }
}

// --- Transition Scale variable to prevent GSAP scale and breathe loops fighting ---
let transitionScale = { value: 1.0 };

// --- Main Animation Loop ---
const clock = new THREE.Clock();

function animate() {
    requestAnimationFrame(animate);
    const time = clock.getElapsedTime();

    // Morph the geometries
    morphVertices(time);

    // Dynamic mesh rotations
    icoMesh.rotation.y = time * 0.12 + scrollProgress * Math.PI * 2.5;
    icoMesh.rotation.x = time * 0.08 + scrollProgress * Math.PI * 0.8;
    wireMesh.rotation.copy(icoMesh.rotation);

    // Smooth linear interpolation of custom material colors
    icoMat.color.lerp(targetIcoColor, 0.05);
    wireMat.color.lerp(targetWireColor, 0.05);
    wireMat.opacity = 0.06 + scrollProgress * 0.15;

    // Soft pulsating scale combined with dynamic page transitions
    const breathe = 1 + Math.sin(time * 1.6) * 0.025;
    const finalScale = breathe * transitionScale.value;
    icoMesh.scale.set(finalScale, finalScale, finalScale);
    wireMesh.scale.set(finalScale, finalScale, finalScale);

    // Floating particle field rotations
    particles.rotation.y = time * 0.015;
    particles.rotation.x = time * 0.008;

    // Follow camera offset on cursor position
    camera.position.x += (mouseX * 5 - camera.position.x) * 0.05;
    camera.position.y += (-mouseY * 3.5 - scrollProgress * 12 - camera.position.y) * 0.05;
    camera.lookAt(scene.position);

    renderer.render(scene, camera);
}

// Handle window resizing
window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
});

// Run 3D animation loop
animate();

// ═══════════════════════════════════════════════════════════
// MULTI-GEOMETRY CONFIGS & BACKGROUND SHAPE SHIFTING
// ═══════════════════════════════════════════════════════════
const PAGE_CONFIGS = {
    'index.html': {
        geom: new THREE.IcosahedronGeometry(4.5, 4),
        wire: new THREE.IcosahedronGeometry(4.55, 4),
        color: 0xFF5F38,
        wireColor: 0x8A2BE2
    },
    'about.html': {
        geom: new THREE.SphereGeometry(4.2, 32, 32),
        wire: new THREE.SphereGeometry(4.25, 32, 32),
        color: 0x00F0FF,
        wireColor: 0xFF1493
    },
    'contact.html': {
        geom: new THREE.TorusGeometry(3.0, 1.2, 16, 100),
        wire: new THREE.TorusGeometry(3.05, 1.2, 16, 100),
        color: 0x8A2BE2,
        wireColor: 0x39FF14
    },
    'support.html': {
        geom: new THREE.TorusKnotGeometry(2.6, 0.8, 100, 16),
        wire: new THREE.TorusKnotGeometry(2.65, 0.8, 100, 16),
        color: 0xFFD700,
        wireColor: 0x00F0FF
    },
    'privacy.html': {
        geom: new THREE.DodecahedronGeometry(4.0, 1),
        wire: new THREE.DodecahedronGeometry(4.05, 1),
        color: 0x39FF14,
        wireColor: 0x0000FF
    },
    'sandbox.html': {
        geom: new THREE.IcosahedronGeometry(4.5, 4),
        wire: new THREE.IcosahedronGeometry(4.55, 4),
        color: 0xFF5F38,
        wireColor: 0x8A2BE2
    }
};

function morphBackground(pageName) {
    let key = 'index.html';
    if (pageName.includes('about.html')) key = 'about.html';
    else if (pageName.includes('contact.html')) key = 'contact.html';
    else if (pageName.includes('support.html')) key = 'support.html';
    else if (pageName.includes('privacy.html')) key = 'privacy.html';
    else if (pageName.includes('sandbox.html')) key = 'sandbox.html';

    const config = PAGE_CONFIGS[key];
    if (!config) return;

    // Scale mesh out, swap geometry and colors, scale back up
    gsap.to(transitionScale, {
        value: 0.0,
        duration: 0.35,
        ease: "power2.in",
        onComplete: () => {
            icoMesh.geometry.dispose();
            wireMesh.geometry.dispose();
            icoMesh.geometry = config.geom;
            wireMesh.geometry = config.wire;

            // Clear original positions cache so new geometry vertex distort works if applicable
            if (icoMesh.geometry.userData) {
                icoMesh.geometry.userData.originalPositions = null;
            }
            if (wireMesh.geometry.userData) {
                wireMesh.geometry.userData.originalPositions = null;
            }

            // Target colors
            targetIcoColor.setHex(config.color);
            targetWireColor.setHex(config.wireColor);

            // Animate back up
            gsap.to(transitionScale, {
                value: 1.0,
                duration: 0.6,
                ease: "back.out(2.0)"
            });
        }
    });
}

// ═══════════════════════════════════════════════════════════
// DYNAMIC AJAX SPA ROUTER (SUPER SMOOTH PAGE TRANSITIONS)
// ═══════════════════════════════════════════════════════════
function initAJAXRouter() {
    document.addEventListener('click', (e) => {
        const link = e.target.closest('a');
        if (!link) return;

        const href = link.getAttribute('href');
        if (!href) return;

        // Ignore absolute external links, mailto, tel
        if (href.startsWith('http') || href.startsWith('mailto:') || href.startsWith('tel:')) return;

        // If it targets an anchor/hash on the current page
        if (href.includes('#')) {
            const parts = href.split('#');
            const targetPage = parts[0] || 'index.html';
            const hash = parts[1];
            const currentPage = window.location.pathname.split('/').pop() || 'index.html';

            if (targetPage === currentPage || (currentPage === '' && targetPage === 'index.html') || (currentPage === 'index.html' && targetPage === '')) {
                // Same page anchor scroll!
                const targetEl = document.getElementById(hash);
                if (targetEl) {
                    e.preventDefault();
                    targetEl.scrollIntoView({ behavior: 'smooth' });
                }
                return;
            }
        }

        // If it's a direct hash link
        if (href.startsWith('#')) return;

        // Standard internal page load via AJAX
        e.preventDefault();
        navigateTo(href);
    });

    window.addEventListener('popstate', () => {
        loadPage(window.location.pathname, false);
    });

    // Mobile Hamburger Menu Toggle Setup
    const hamburger = document.getElementById('navHamburger');
    const navLinks = document.querySelector('.nav-links');
    
    if (hamburger && navLinks) {
        hamburger.addEventListener('click', () => {
            hamburger.classList.toggle('active');
            navLinks.classList.toggle('active');
            
            // Disable or enable body scrolling when menu is active
            if (navLinks.classList.contains('active')) {
                document.body.style.overflow = 'hidden';
            } else {
                document.body.style.overflow = '';
            }
        });

        // Close mobile menu when any nav link item is clicked (for AJAX loads)
        document.querySelectorAll('.nav-link-item').forEach(item => {
            item.addEventListener('click', () => {
                hamburger.classList.remove('active');
                navLinks.classList.remove('active');
                document.body.style.overflow = '';
            });
        });
    }
}

function navigateTo(url) {
    const basePath = window.location.pathname.substring(0, window.location.pathname.lastIndexOf('/') + 1);
    
    // Pretty URL segment formatting
    let prettySegment = url;
    if (prettySegment === 'index.html' || prettySegment === '') {
        prettySegment = 'home'; // Show as /home in address bar
    } else if (prettySegment.endsWith('.html')) {
        prettySegment = prettySegment.replace('.html', ''); // Strip .html
    }
    
    const targetUrl = basePath + prettySegment;
    history.pushState(null, null, targetUrl);
    loadPage(url, true); // Fetch the actual .html file internally
}

function loadPage(url, shouldPushHistory) {
    // Strip hash or query parameters from URL to parse correct target filename
    const cleanUrl = url.split('#')[0].split('?')[0];
    let filename = cleanUrl.substring(cleanUrl.lastIndexOf('/') + 1) || 'index.html';
    
    // Resolve pretty URL tokens back to physical files
    if (filename === 'home' || filename === '') {
        filename = 'index.html';
    } else if (filename && !filename.includes('.')) {
        filename = filename + '.html';
    }
    
    // Crossfade slide-down container transition
    gsap.to('.scroll-container', {
        opacity: 0,
        y: 35,
        duration: 0.35,
        ease: "power2.in",
        onComplete: () => {
            fetch(filename)
                .then(res => {
                    if (!res.ok) throw new Error('fetch_error');
                    return res.text();
                })
                .then(html => {
                    const parser = new DOMParser();
                    const doc = parser.parseFromString(html, 'text/html');
                    
                    // Replace interior page contents
                    const newContent = doc.querySelector('.scroll-container').innerHTML;
                    document.querySelector('.scroll-container').innerHTML = newContent;
                    document.title = doc.title;

                    // Dynamically animate geometry and color parameters
                    morphBackground(filename);

                    // Re-register links active state indicators
                    updateActiveNavLinks(filename);

                    // Fade back in
                    gsap.to('.scroll-container', {
                        opacity: 1,
                        y: 0,
                        duration: 0.6,
                        ease: "power3.out"
                    });

                    // Instantly scroll window to top
                    window.scrollTo({ top: 0, behavior: 'instant' });

                    // Rebind dynamic interactive components
                    bootstrapPage(filename);
                })
                .catch(err => {
                    console.error('AJAX Transition fail, falling back to window redirect:', err);
                    window.location.href = filename;
                });
        }
    });
}

function updateActiveNavLinks(filename) {
    document.querySelectorAll('.nav-link-item').forEach(link => {
        link.classList.remove('active');
        const href = link.getAttribute('href');
        if (href === filename || (filename === 'index.html' && (href.startsWith('index.html') || href === 'index.html'))) {
            link.classList.add('active');
        }
    });
}

function bootstrapPage(filename) {
    // Rebind universal controls
    initMagneticButtons();
    initTiltCards();

    // Rebind ScrollTrigger metrics, killing and fully reverting previous styling to unlock scrolling!
    gsap.registerPlugin(ScrollTrigger);
    ScrollTrigger.getAll().forEach(t => t.kill(true));
    document.body.style.overflow = '';
    document.documentElement.style.overflow = '';
    
    initGSAPScrollTriggers(filename);

    // Bootstrap specific page initializations
    if (filename === 'index.html' || filename === '') {
        initIndexPage();
    } else if (filename.includes('support.html')) {
        initSupportPage();
    } else if (filename.includes('contact.html')) {
        initContactPage();
    } else if (filename.includes('sandbox.html')) {
        initSandboxPage();
    }
}

// ═══════════════════════════════════════════════════════════
// GSAP SCROLLTRIGGERS INITIALIZATION
// ═══════════════════════════════════════════════════════════
function initGSAPScrollTriggers(filename) {
    // Premium entrance animation for subpage containers
    if (document.querySelector(".subpage-content-wrapper")) {
        gsap.from(".subpage-content-wrapper > *", {
            y: 40, opacity: 0, duration: 0.8, stagger: 0.15,
            ease: "power3.out"
        });
    }

    // Only apply animations to loaded components present in DOM
    if (document.querySelector(".hero-content")) {
        gsap.from(".hero-content > *", {
            y: 50, opacity: 0, duration: 1, stagger: 0.12,
            ease: "power3.out", delay: 0.2
        });
    }

    if (document.querySelector(".hero-mockup-wrapper")) {
        gsap.from(".hero-mockup-wrapper", {
            x: 80, opacity: 0, scale: 0.95, duration: 1.2,
            ease: "power3.out", delay: 0.5
        });
    }

    if (document.querySelector('.bento-card')) {
        gsap.utils.toArray('.bento-card').forEach((card, i) => {
            gsap.from(card, {
                scrollTrigger: { trigger: card, start: "top 88%", once: true },
                y: 45, opacity: 0, duration: 0.65,
                delay: (i % 3) * 0.12, ease: "power2.out"
            });
        });
    }

    if (document.querySelector('.changelog-item')) {
        gsap.utils.toArray('.changelog-item').forEach((item) => {
            ScrollTrigger.create({
                trigger: item,
                start: "top 82%",
                once: true,
                onEnter: () => item.classList.add('visible'),
            });
        });
    }

    if (document.querySelector('.security-card')) {
        gsap.from('.security-card', {
            scrollTrigger: { trigger: '.security-card', start: "top 78%", once: true },
            y: 50, opacity: 0, duration: 0.8, ease: "power2.out"
        });
    }

    if (document.querySelector('.final-block')) {
        gsap.from('.final-block', {
            scrollTrigger: { trigger: '.final-block', start: "top 82%", once: true },
            y: 60, opacity: 0, scale: 0.97, duration: 0.9, ease: "power3.out"
        });
    }
}

// ═══════════════════════════════════════════════════════════
// INTERACTIVE COMPONENT UTILITIES
// ═══════════════════════════════════════════════════════════
function initTiltCards() {
    document.querySelectorAll('.tilt-card').forEach(card => {
        card.addEventListener('mousemove', (e) => {
            const rect = card.getBoundingClientRect();
            const x = ((e.clientX - rect.left) / rect.width - 0.5) * 15;
            const y = ((e.clientY - rect.top) / rect.height - 0.5) * -15;
            card.style.transform = `perspective(1000px) rotateX(${y}deg) rotateY(${x}deg) translateZ(12px)`;
        });
        card.addEventListener('mouseleave', () => {
            card.style.transform = `perspective(1000px) rotateX(0deg) rotateY(0deg) translateZ(0px)`;
        });
    });
}

function initMagneticButtons() {
    document.querySelectorAll('.magnetic').forEach(btn => {
        btn.addEventListener('mousemove', (e) => {
            const rect = btn.getBoundingClientRect();
            const x = e.clientX - rect.left - rect.width / 2;
            const y = e.clientY - rect.top - rect.height / 2;
            gsap.to(btn, { x: x * 0.35, y: y * 0.35, duration: 0.35, ease: "power2.out" });
        });
        btn.addEventListener('mouseleave', () => {
            gsap.to(btn, { x: 0, y: 0, duration: 0.65, ease: "elastic.out(1.1, 0.4)" });
        });
    });
}

// ═══════════════════════════════════════════════════════════
// INDEX PAGE SPECIFIC INTERACTIONS & FIRESTORE REVIEWS
// ═══════════════════════════════════════════════════════════
const FIREBASE_REST_BASE = "https://firestore.googleapis.com/v1/projects/rotty-music/databases/(default)/documents";
const API_KEY = "AIzaSyDkD9uaVanSvrsAg_Myg7mYKW0GSjB0t7w";

// Global audio streaming declaration
const audioFile = new Audio('song.mp3');
audioFile.loop = true;
audioFile.volume = 0.5;

function decodeFirestore(doc) {
    const fields = doc.fields || {};
    const result = {};
    for (const key in fields) {
        const val = fields[key];
        if (val.stringValue !== undefined) result[key] = val.stringValue;
        else if (val.doubleValue !== undefined) result[key] = parseFloat(val.doubleValue);
        else if (val.integerValue !== undefined) result[key] = parseInt(val.integerValue);
        else if (val.booleanValue !== undefined) result[key] = val.booleanValue;
    }
    return result;
}

function initIndexPage() {
    // 1. Mockup audio setup
    const mockupPlayBtn = document.getElementById('mockupPlayBtn');
    const visualizerWaves = document.querySelector('.visualizer-waves');
    
    if (mockupPlayBtn && visualizerWaves) {
        visualizerWaves.style.display = 'none';
        mockupPlayBtn.textContent = '▶';
        
        // Remove existing clone listeners
        const newPlayBtn = mockupPlayBtn.cloneNode(true);
        mockupPlayBtn.parentNode.replaceChild(newPlayBtn, mockupPlayBtn);
        
        newPlayBtn.addEventListener('click', () => {
            if (newPlayBtn.textContent === '▶') {
                newPlayBtn.textContent = '⏸';
                newPlayBtn.style.background = '#8A2BE2';
                newPlayBtn.style.boxShadow = '0 5px 15px rgba(138, 43, 226, 0.4)';
                visualizerWaves.style.display = 'flex';
                particlesMat.color.setHex(0xFF5F38);
                audioFile.play().catch(err => console.log("Audio play blocked:", err));
            } else {
                newPlayBtn.textContent = '▶';
                newPlayBtn.style.background = '#FF5F38';
                newPlayBtn.style.boxShadow = '0 5px 15px rgba(255, 95, 56, 0.4)';
                visualizerWaves.style.display = 'none';
                particlesMat.color.setHex(0x00F0FF);
                audioFile.pause();
            }
        });
    }

    // 2. Audio sandbox EQ simulation toggles
    const sandboxToggles = document.querySelectorAll('.sandbox-toggle');
    const freqMesh = document.getElementById('freqMesh');
    const visualizerTag = document.getElementById('visualizerTag');

    if (sandboxToggles && freqMesh && visualizerTag) {
        sandboxToggles.forEach(btn => {
            btn.addEventListener('click', () => {
                sandboxToggles.forEach(b => b.classList.remove('active'));
                btn.classList.add('active');

                const effect = btn.dataset.effect;
                freqMesh.className = 'freq-mesh';
                const bars = freqMesh.querySelectorAll('span');

                if (effect === 'normal') {
                    visualizerTag.textContent = 'NORMAL STEREO MODE';
                    targetIcoColor.setHex(0xFF5F38);
                    targetWireColor.setHex(0x8A2BE2);
                    bars[0].style.setProperty('--h', '30%');
                    bars[1].style.setProperty('--h', '55%');
                    bars[2].style.setProperty('--h', '80%');
                    bars[3].style.setProperty('--h', '40%');
                    bars[4].style.setProperty('--h', '90%');
                    bars[5].style.setProperty('--h', '60%');
                    bars[6].style.setProperty('--h', '30%');
                    bars[7].style.setProperty('--h', '45%');
                    bars[8].style.setProperty('--h', '75%');
                    bars[9].style.setProperty('--h', '50%');
                    bars[10].style.setProperty('--h', '95%');
                    bars[11].style.setProperty('--h', '35%');
                    bars[12].style.setProperty('--h', '60%');
                    bars[13].style.setProperty('--h', '85%');
                    bars[14].style.setProperty('--h', '50%');
                } else if (effect === 'bass') {
                    freqMesh.classList.add('bass');
                    visualizerTag.textContent = 'BASS BOOST ACTIVE (+12DB SUB-BOOST)';
                    targetIcoColor.setHex(0x39FF14);
                    targetWireColor.setHex(0x00F0FF);
                    bars[0].style.setProperty('--h', '98%');
                    bars[1].style.setProperty('--h', '95%');
                    bars[2].style.setProperty('--h', '90%');
                    bars[3].style.setProperty('--h', '85%');
                    bars[4].style.setProperty('--h', '60%');
                    bars[5].style.setProperty('--h', '40%');
                    bars[6].style.setProperty('--h', '30%');
                    bars[7].style.setProperty('--h', '20%');
                    bars[8].style.setProperty('--h', '15%');
                    bars[9].style.setProperty('--h', '10%');
                    bars[10].style.setProperty('--h', '8%');
                    bars[11].style.setProperty('--h', '6%');
                    bars[12].style.setProperty('--h', '5%');
                    bars[13].style.setProperty('--h', '4%');
                    bars[14].style.setProperty('--h', '4%');
                } else if (effect === 'orbit') {
                    freqMesh.classList.add('orbit');
                    visualizerTag.textContent = '8D SPATIAL ORBIT IN COMSOS SPACE';
                    targetIcoColor.setHex(0x00F0FF);
                    targetWireColor.setHex(0x8A2BE2);
                    bars.forEach((bar, idx) => {
                        bar.style.setProperty('--h', `${40 + Math.sin(idx * 0.7) * 35}%`);
                    });
                } else if (effect === 'vocal') {
                    freqMesh.classList.add('vocal');
                    visualizerTag.textContent = 'VOCAL FORWARD (CLEAR HIGHS & MIDRANGE)';
                    targetIcoColor.setHex(0x8A2BE2);
                    targetWireColor.setHex(0xFF5F38);
                    bars[0].style.setProperty('--h', '15%');
                    bars[1].style.setProperty('--h', '25%');
                    bars[2].style.setProperty('--h', '35%');
                    bars[3].style.setProperty('--h', '50%');
                    bars[4].style.setProperty('--h', '70%');
                    bars[5].style.setProperty('--h', '90%');
                    bars[6].style.setProperty('--h', '98%');
                    bars[7].style.setProperty('--h', '95%');
                    bars[8].style.setProperty('--h', '85%');
                    bars[9].style.setProperty('--h', '65%');
                    bars[10].style.setProperty('--h', '45%');
                    bars[11].style.setProperty('--h', '35%');
                    bars[12].style.setProperty('--h', '20%');
                    bars[13].style.setProperty('--h', '15%');
                    bars[14].style.setProperty('--h', '10%');
                }
            });
        });
    }

    // 3. Interactive Star Picker rating
    const stars = document.querySelectorAll('.picker-star');
    const inputRating = document.getElementById('selected-rating');

    if (stars && inputRating) {
        stars.forEach(star => {
            star.addEventListener('mouseenter', () => {
                const rating = parseInt(star.dataset.rating);
                stars.forEach(s => {
                    const r = parseInt(s.dataset.rating);
                    s.classList.toggle('hovered', r <= rating);
                });
            });

            star.addEventListener('mouseleave', () => {
                stars.forEach(s => s.classList.remove('hovered'));
            });

            star.addEventListener('click', () => {
                const rating = parseInt(star.dataset.rating);
                inputRating.value = rating;
                stars.forEach(s => {
                    const r = parseInt(s.dataset.rating);
                    s.classList.toggle('selected', r <= rating);
                });
            });
        });
    }

    // 4. Bind submit review form trigger
    const reviewForm = document.getElementById('review-submit-form');
    if (reviewForm) {
        reviewForm.addEventListener('submit', (e) => {
            e.preventDefault();
            submitUserReview();
        });
    }

    // 5. Load existing reviews from database
    loadDatabaseReviews();
}

let loadedReviewsData = [];

function loadDatabaseReviews() {
    const feed = document.getElementById('reviewsFeed');
    if (!feed) return;

    fetch(`${FIREBASE_REST_BASE}/reviews?key=${API_KEY}`)
        .then(res => {
            if (!res.ok) throw new Error('database_error');
            return res.json();
        })
        .then(data => {
            const docs = data.documents || [];
            loadedReviewsData = docs.map(d => decodeFirestore(d));
            
            // Sort reviews by timestamp descending
            loadedReviewsData.sort((a,b) => (b.timestamp || 0) - (a.timestamp || 0));

            // Populate statistics calculations
            updateReviewStatistics();

            // Clear skeletons and render reviews list
            feed.innerHTML = '';
            if (loadedReviewsData.length === 0) {
                feed.innerHTML = '<div class="review-card glass-card" style="justify-content: center;"><p style="color: var(--text-muted);">No reviews posted yet. Be the first one!</p></div>';
                return;
            }

            loadedReviewsData.forEach(rev => {
                feed.appendChild(createReviewCardDOM(rev));
            });
        })
        .catch(err => {
            console.error('Failed to query reviews:', err);
            feed.innerHTML = '<div class="review-card glass-card" style="justify-content: center;"><p style="color: var(--accent-red);">Error loading reviews from database.</p></div>';
        });
}

function updateReviewStatistics() {
    const totalCount = loadedReviewsData.length;
    const avgRatingHeader = document.getElementById('avg-rating');
    const totalReviewsLabel = document.getElementById('total-reviews-count');
    const avgStarsLabel = document.getElementById('avg-stars');

    if (!avgRatingHeader) return;

    if (totalCount === 0) {
        avgRatingHeader.textContent = "0.0";
        totalReviewsLabel.textContent = "Based on 0 reviews";
        avgStarsLabel.textContent = "★★★★★";
        return;
    }

    let sum = 0;
    const distribution = { 5: 0, 4: 0, 3: 0, 2: 0, 1: 0 };

    loadedReviewsData.forEach(r => {
        const rating = Math.min(5, Math.max(1, Math.round(r.rating || 0)));
        distribution[rating]++;
        sum += (r.rating || 0);
    });

    const average = (sum / totalCount).toFixed(1);
    avgRatingHeader.textContent = average;
    totalReviewsLabel.textContent = `Based on ${totalCount} reviews`;

    // Star character rounding logic
    const fullStars = Math.round(average);
    avgStarsLabel.textContent = "★".repeat(fullStars) + "☆".repeat(5 - fullStars);

    // Update graphical metric bars
    for (let i = 1; i <= 5; i++) {
        const pct = ((distribution[i] / totalCount) * 100).toFixed(0);
        const fill = document.getElementById(`bar-${i}`);
        const count = document.getElementById(`count-${i}`);
        if (fill) fill.style.width = `${pct}%`;
        if (count) count.textContent = distribution[i];
    }
}

function createReviewCardDOM(rev) {
    const card = document.createElement('div');
    card.className = 'review-card glass-card';

    const initial = (rev.name || 'G').charAt(0).toUpperCase();
    const cleanName = rev.name || 'Anonymous User';
    const stars = "★".repeat(Math.round(rev.rating || 5)) + "☆".repeat(5 - Math.round(rev.rating || 5));
    
    // Format timestamp string
    let dateStr = 'Recently';
    if (rev.timestamp) {
        const dateObj = new Date(rev.timestamp);
        dateStr = dateObj.toLocaleDateString('en-US', { year: 'numeric', month: 'short', day: 'numeric' });
    }

    card.innerHTML = `
        <div class="review-avatar-box">${initial}</div>
        <div class="review-card-content">
            <div class="review-card-header">
                <h4>${cleanName}</h4>
                <div class="review-card-stars">${stars}</div>
            </div>
            <div class="review-card-date">Submitted: ${dateStr}</div>
            <p class="review-card-comment">${rev.comment || ''}</p>
        </div>
    `;
    return card;
}

function submitUserReview() {
    const inputRating = document.getElementById('selected-rating');
    const inputName = document.getElementById('reviewer-name');
    const inputComment = document.getElementById('reviewer-comment');
    const btn = document.getElementById('reviewSubmitBtn');
    const loader = document.getElementById('submitLoader');

    const ratingVal = parseFloat(inputRating.value);
    if (!ratingVal || ratingVal <= 0) {
        alert('Please click on the stars to select your rating.');
        return;
    }

    const name = inputName.value.trim();
    const comment = inputComment.value.trim();

    // Prevent blanks
    if (!name || !comment) return;

    btn.classList.add('loading');
    if (loader) loader.style.display = 'inline-block';

    const data = {
        fields: {
            name: { stringValue: name },
            rating: { doubleValue: ratingVal },
            comment: { stringValue: comment },
            timestamp: { doubleValue: Date.now() }
        }
    };

    fetch(`${FIREBASE_REST_BASE}/reviews?key=${API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    })
    .then(res => {
        btn.classList.remove('loading');
        if (loader) loader.style.display = 'none';

        if (res.ok) {
            btn.classList.add('success');
            btn.querySelector('.btn-text').textContent = 'Submitted! ✓';

            // Retrieve generated object response to prepend
            return res.json().then(savedDoc => {
                const parsed = decodeFirestore(savedDoc);
                
                // Add dynamically to local array
                loadedReviewsData.unshift(parsed);

                // Live repaint review blocks
                updateReviewStatistics();
                const feed = document.getElementById('reviewsFeed');
                if (feed) {
                    // Remove blank status message if present
                    if (loadedReviewsData.length === 1) feed.innerHTML = '';
                    feed.insertBefore(createReviewCardDOM(parsed), feed.firstChild);
                }

                // Clear input form
                setTimeout(() => {
                    btn.classList.remove('success');
                    btn.querySelector('.btn-text').textContent = 'Submit Review';
                    document.getElementById('review-submit-form').reset();
                    // Reset picker stars active highlight
                    document.querySelectorAll('.picker-star').forEach(s => s.classList.remove('selected'));
                    inputRating.value = 0;
                }, 4000);
            });
        } else {
            alert('Failed to save review. Please check your network connection.');
        }
    })
    .catch(err => {
        console.error(err);
        btn.classList.remove('loading');
        if (loader) loader.style.display = 'none';
        alert('Database timeout. Please try again later.');
    });
}

// ═══════════════════════════════════════════════════════════
// SUPPORT PORTAL PAYMENT GENERATION & VALIDATION
// ═══════════════════════════════════════════════════════════
function initSupportPage() {
    const qrContainer = document.getElementById('qrcode');
    if (qrContainer) {
        qrContainer.innerHTML = '';
        new QRCode(qrContainer, {
            text: "upi://pay?pa=8532999011@ybl&pn=Kartik&am=99&cu=INR&tn=Rotty%20Music%20Supporter",
            width: 160,
            height: 160,
            colorDark : "#000000",
            colorLight : "#ffffff",
            correctLevel : QRCode.CorrectLevel.H
        });
    }

    const form = document.getElementById('supporter-submit-form');
    if (form) {
        form.addEventListener('submit', (e) => {
            e.preventDefault();
            submitSupporterPayment();
        });
    }
}

function submitSupporterPayment() {
    const inputEmail = document.getElementById('supporter-email');
    const inputUtr = document.getElementById('supporter-utr');
    const btn = document.getElementById('supportSubmitBtn');
    const loader = document.getElementById('supportLoader');

    const email = inputEmail.value.trim().toLowerCase();
    const utr = inputUtr.value.trim();

    if (!email || !utr) return;

    // Validate 12-digit reference
    const utrRegex = /^\d{12}$/;
    if (!utrRegex.test(utr)) {
        alert('Please enter a valid 12-digit numeric UPI UTR Reference Number.');
        return;
    }

    btn.classList.add('loading');
    if (loader) loader.style.display = 'inline-block';

    const data = {
        fields: {
            uid: { stringValue: 'web_guest' },
            email: { stringValue: email },
            utr: { stringValue: utr },
            status: { stringValue: 'pending' },
            submittedAt: { stringValue: new Date().toISOString() }
        }
    };

    fetch(`${FIREBASE_REST_BASE}/payments_pending/${utr}?key=${API_KEY}`, {
        method: 'PATCH', // Overwrites or creates unique doc identified by UTR
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    })
    .then(res => {
        btn.classList.remove('loading');
        if (loader) loader.style.display = 'none';

        if (res.ok) {
            btn.classList.add('success');
            btn.querySelector('.btn-text').textContent = 'Verification Submitted! ✓';
            
            setTimeout(() => {
                btn.classList.remove('success');
                btn.querySelector('.btn-text').textContent = 'Verify & Submit Payment';
                document.getElementById('supporter-submit-form').reset();
            }, 5000);
        } else {
            alert('Server error verifying transaction. Double check details.');
        }
    })
    .catch(err => {
        console.error(err);
        btn.classList.remove('loading');
        if (loader) loader.style.display = 'none';
        alert('Verification server timeout. Try again.');
    });
}

// ═══════════════════════════════════════════════════════════
// CONTACT MESSAGE LOGGER TO FIRESTORE
// ═══════════════════════════════════════════════════════════
function initContactPage() {
    const form = document.getElementById('contact-submit-form');
    if (form) {
        form.addEventListener('submit', (e) => {
            e.preventDefault();
            submitContactMessage();
        });
    }
}

function submitContactMessage() {
    const inputName = document.getElementById('contact-name');
    const inputEmail = document.getElementById('contact-email');
    const inputSubject = document.getElementById('contact-subject');
    const inputMsg = document.getElementById('contact-message');
    const btn = document.getElementById('contactSubmitBtn');
    const loader = document.getElementById('contactLoader');

    const name = inputName.value.trim();
    const email = inputEmail.value.trim().toLowerCase();
    const subject = inputSubject.value.trim();
    const message = inputMsg.value.trim();

    if (!name || !email || !subject || !message) return;

    btn.classList.add('loading');
    if (loader) loader.style.display = 'inline-block';

    const data = {
        fields: {
            name: { stringValue: name },
            email: { stringValue: email },
            subject: { stringValue: subject },
            message: { stringValue: message },
            submittedAt: { stringValue: new Date().toISOString() }
        }
    };

    fetch(`${FIREBASE_REST_BASE}/website_contacts?key=${API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    })
    .then(res => {
        btn.classList.remove('loading');
        if (loader) loader.style.display = 'none';

        if (res.ok) {
            btn.classList.add('success');
            btn.querySelector('.btn-text').textContent = 'Message Logged Successfully! ✓';
            
            setTimeout(() => {
                btn.classList.remove('success');
                btn.querySelector('.btn-text').textContent = 'Send Message';
                document.getElementById('contact-submit-form').reset();
            }, 5000);
        } else {
            alert('Failed to transmit message. Check details.');
        }
    })
    .catch(err => {
        console.error(err);
        btn.classList.remove('loading');
        if (loader) loader.style.display = 'none';
        alert('Server timeout. Try again.');
    });
}

// ═══════════════════════════════════════════════════════════
// INTERACTIVE SANDBOX TOUR CONTROLLERS & DATA
// ═══════════════════════════════════════════════════════════
const SANDBOX_TOUR_CONFIGS = {
    'home': {
        geom: new THREE.IcosahedronGeometry(4.5, 4),
        wire: new THREE.IcosahedronGeometry(4.55, 4),
        color: 0xFF5F38,
        wireColor: 0x8A2BE2,
        accent: '#FF5F38'
    },
    'concert': {
        geom: new THREE.SphereGeometry(4.2, 32, 32),
        wire: new THREE.SphereGeometry(4.25, 32, 32),
        color: 0xFF003C,
        wireColor: 0x00F0FF,
        accent: '#FF003C'
    },
    'focus': {
        geom: new THREE.TorusGeometry(3.0, 1.2, 16, 100),
        wire: new THREE.TorusGeometry(3.05, 1.2, 16, 100),
        color: 0x39FF14,
        wireColor: 0x0000FF,
        accent: '#39FF14'
    },
    'sync': {
        geom: new THREE.TorusKnotGeometry(2.6, 0.8, 100, 16),
        wire: new THREE.TorusKnotGeometry(2.65, 0.8, 100, 16),
        color: 0x00F0FF,
        wireColor: 0x8A2BE2,
        accent: '#00F0FF'
    },
    'labs': {
        geom: new THREE.DodecahedronGeometry(4.0, 1),
        wire: new THREE.DodecahedronGeometry(4.05, 1),
        color: 0x8A2BE2,
        wireColor: 0x39FF14,
        accent: '#8A2BE2'
    },
    'vault': {
        geom: new THREE.IcosahedronGeometry(4.4, 2),
        wire: new THREE.IcosahedronGeometry(4.45, 2),
        color: 0xFF007F,
        wireColor: 0x550000,
        accent: '#FF007F'
    }
};

const SANDBOX_DETAILS = {
    'home': {
        badge: 'HOME ENGINE',
        title: 'Rotty Music Home Universe',
        description: 'Rotty Music ka main home dashboard. Mobile view me dynamic horizontal scroll "Scenes", "Concert", "Labs" shortcuts, smart "AI DJ" switcher, streak modules aur quick listening history dynamic album cover art ke saath load hoti hai. Desktop / Laptop view me side-by-side premium dynamic navigation, ramu user profile (Supporter 💖 badge ke saath) aur fully populated play metrics dashboard seamlessly render hote hain.',
        points: [
            '<span>✦</span> <strong>Fully Customizable Sidebar</strong>: Desktop view has interactive playlist controls.',
            '<span>✦</span> <strong>AI DJ Integration</strong>: Toggle for customized queue recommendation.',
            '<span>✦</span> <strong>Streak Engine</strong>: Daily listening targets tracked in real-time.',
            '<span>✦</span> <strong>Continue Listening</strong>: Swipeable horizontal grids for active albums.'
        ]
    },
    'concert': {
        badge: 'CONCERT ENGINE',
        title: '8D Spatial Concert & Sync Lyrics',
        description: 'Concert Player screen audio playback ko real-time 3D spatial orbit audio dome me transform kar deta hai. Sync Lyrics feature me dynamic lyrics characters cinema screen-perspective perspective vectors space me highlight hokar move karte hain. Album art details deep drop glows emit karti hain.',
        points: [
            '<span>✦</span> <strong>8D Volume Orbit</strong>: Periodically pans sound 360-degrees around your head.',
            '<span>✦</span> <strong>3D Cinema Lyrics</strong>: Perspective scrolling verses highlight active vocals.',
            '<span>✦</span> <strong>Translucent Glare</strong>: Frosted glass panel overlays display synchronized lyrics.',
            '<span>✦</span> <strong>Cyberpunk Visualizer</strong>: Wave bars pulse dynamically based on track beats.'
        ]
    },
    'focus': {
        badge: 'FOCUS CORE',
        title: 'Focus Lock Flow State Timer',
        description: 'Focus Mode block distraction utilities built over the Pomodoro technique. Mobile view has completely black layout with a circular ready progress dial. PC view has widescreen "FLOW STATE TIMER" containing slide controls to set intervals, warning disclaimers, and interactive flow session locking buttons.',
        points: [
            '<span>✦</span> <strong>Flow State Clock</strong>: High-contrast 25-minute Pomodoro timer countdown.',
            '<span>✦</span> <strong>Sliding Intervals</strong>: Interactive range controller scales active timers.',
            '<span>✦</span> <strong>Anti-Distraction Shield</strong>: Temporarily locks external page navigation.',
            '<span>✦</span> <strong>Mini Audio Pill</strong>: Float controls for play/pause tucked at bottom.'
        ]
    },
    'sync': {
        badge: 'SYNC HUB',
        title: 'Rotty Connect & Party Sync',
        description: 'Multi-device sync controller built over lightning-fast databases. Single room sync enables a user to play tracks on PC and control playback actions (play, pause, next, volume) instantly from their mobile phone, or join public sessions to stream together.',
        points: [
            '<span>✦</span> <strong>Host a Room</strong>: Generates unique code string to stream together.',
            '<span>✦</span> <strong>Join Room Session</strong>: Connect and link controller actions from any phone.',
            '<span>✦</span> <strong>Real-time Syncing</strong>: Remote play, pause, volume sliders, and track skipping.',
            '<span>✦</span> <strong>Live Chat Room</strong>: Dynamic messaging board (Aap sabhi chatpate logo...) built-in.'
        ]
    },
    'labs': {
        badge: 'LABS ENGINE',
        title: 'ROTTY Labs Experimental Kit',
        description: 'Advanced audio customizers and equalizers dashboard. Contains multiple responsive toggles and sliders enabling users to activate Sleep Oracle, time-travel mood stations with Time Machine, Infinite Blend cross-fading, Reverse Discover, and customized 8D presets.',
        points: [
            '<span>✦</span> <strong>Studio Lab EQ</strong>: Real-time hardware volume, frequency and bass orbits.',
            '<span>✦</span> <strong>Aura Theme follows</strong>: Fluid art bleeds and colors adapt to album cover arts.',
            '<span>✦</span> <strong>Sleep Oracle</strong>: Ambient background layers with automated off-timers.',
            '<span>✦</span> <strong>3x3 Modular Dashboard</strong>: Responsive widgets control experimental parameters.'
        ]
    },
    'vault': {
        badge: 'SECURE CORE',
        title: 'Private Vault Security',
        description: 'PIN-protected private library storage layer. Keeps personal local files, audio catalogs, and custom playlists hidden from standard browser search results and standard listening decks, securing files behind local AES-256-CBC hash pipelines.',
        points: [
            '<span>✦</span> <strong>Lock Status Badge</strong>: High-contrast glowing red padlock icon.',
            '<span>✦</span> <strong>Strict PIN Entry</strong>: 4-digit numeric container blocks brute-force vectors.',
            '<span>✦</span> <strong>Stateless Recovery</strong>: Dynamic reset prompts wipes security credentials safely.',
            '<span>✦</span> <strong>Ghost Encryption</strong>: Completely offline storage logic with zero metadata leaks.'
        ]
    }
};

function morphSandboxBackground(tourKey) {
    const config = SANDBOX_TOUR_CONFIGS[tourKey];
    if (!config) return;

    // Scale mesh out, swap geometry and colors, scale back up
    gsap.to(transitionScale, {
        value: 0.0,
        duration: 0.35,
        ease: "power2.in",
        onComplete: () => {
            icoMesh.geometry.dispose();
            wireMesh.geometry.dispose();
            icoMesh.geometry = config.geom;
            wireMesh.geometry = config.wire;

            // Clear original positions cache so new geometry vertex distort works if applicable
            if (icoMesh.geometry.userData) {
                icoMesh.geometry.userData.originalPositions = null;
            }
            if (wireMesh.geometry.userData) {
                wireMesh.geometry.userData.originalPositions = null;
            }

            // Target colors
            targetIcoColor.setHex(config.color);
            targetWireColor.setHex(config.wireColor);

            // Animate back up
            gsap.to(transitionScale, {
                value: 1.0,
                duration: 0.6,
                ease: "back.out(2.0)"
            });
        }
    });
}

function initSandboxPage() {
    const buttons = document.querySelectorAll('.tour-btn');
    const laptopImg = document.getElementById('laptop-screen-img');
    const mobileImg = document.getElementById('mobile-screen-img');

    const badgeEl = document.getElementById('details-badge-el');
    const titleEl = document.getElementById('details-title-el');
    const descEl = document.getElementById('details-desc-el');
    const pointsEl = document.getElementById('details-points-el');
    const detailsCard = document.getElementById('sandbox-details-card');

    if (!buttons || !laptopImg || !mobileImg) return;

    buttons.forEach(btn => {
        btn.addEventListener('click', () => {
            if (btn.classList.contains('active')) return;

            const tourKey = btn.dataset.tour;
            const config = SANDBOX_TOUR_CONFIGS[tourKey];
            const info = SANDBOX_DETAILS[tourKey];

            if (!config || !info) return;

            // Remove active classes
            buttons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');

            // Reset manual inline active colors
            buttons.forEach(b => {
                b.style.boxShadow = '';
                b.style.borderColor = '';
            });

            // Set active state inline colors on selected element
            btn.style.boxShadow = `0 0 20px ${config.accent}40`;
            btn.style.borderColor = config.accent;

            // Blur & Crossfade screens
            laptopImg.classList.add('transition-fade');
            mobileImg.classList.add('transition-fade');

            setTimeout(() => {
                // Update screenshot filepaths
                let pcSrc = 'homepc.png';
                let mobileSrc = 'homemobile.jpg';

                if (tourKey === 'concert') {
                    pcSrc = 'concertpc.png';
                    mobileSrc = 'concertmobile.jpg';
                } else if (tourKey === 'focus') {
                    pcSrc = 'focusmodepc.png';
                    mobileSrc = 'focusmodemobile.jpg';
                } else if (tourKey === 'sync') {
                    pcSrc = 'partysyncpc.png';
                    mobileSrc = 'partysyncmobile.jpg';
                } else if (tourKey === 'labs') {
                    pcSrc = 'rottylabpc.png';
                    mobileSrc = 'rottylabmobile.jpg';
                } else if (tourKey === 'vault') {
                    pcSrc = 'vaultpc.png';
                    mobileSrc = 'vaultmobile.jpg';
                }

                laptopImg.src = `screenshots/${pcSrc}`;
                mobileImg.src = `screenshots/${mobileSrc}`;

                // Update Dynamic Details Panel Content
                badgeEl.textContent = info.badge;
                badgeEl.style.color = config.accent;
                badgeEl.style.borderColor = `${config.accent}4d`;
                badgeEl.style.background = `${config.accent}1e`;

                titleEl.textContent = info.title;
                descEl.textContent = info.description;
                
                // Rebuild bullet list points
                pointsEl.innerHTML = '';
                info.points.forEach(pt => {
                    const ptLi = document.createElement('div');
                    ptLi.className = 'point-item';
                    ptLi.innerHTML = pt;
                    ptLi.querySelector('span').style.color = config.accent;
                    pointsEl.appendChild(ptLi);
                });

                // Update border glow color
                detailsCard.style.borderColor = config.accent;

                // Remove blur & fade classes
                laptopImg.classList.remove('transition-fade');
                mobileImg.classList.remove('transition-fade');
            }, 280);

            // Morph 3D background shape and color parameters
            morphSandboxBackground(tourKey);
        });
    });
}

// ═══════════════════════════════════════════════════════════
// INITIAL PAGE BOOTSTRAP TRIGGER
// ═══════════════════════════════════════════════════════════
initAJAXRouter();

// Establish initial startup setup based on absolute URL
const initialUrl = window.location.pathname;
const initialFilename = initialUrl.substring(initialUrl.lastIndexOf('/') + 1) || 'index.html';

// Initial background geometry setup
morphBackground(initialFilename);
updateActiveNavLinks(initialFilename);
bootstrapPage(initialFilename);


