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
    const pos = icoGeo.attributes.position.array;
    const wirePos = wireGeo.attributes.position.array;
    for (let i = 0; i < pos.length; i += 3) {
        const ox = originalPositions[i];
        const oy = originalPositions[i + 1];
        const oz = originalPositions[i + 2];
        
        // Complex trigonometric noise logic
        const noise = Math.sin(time * 1.8 + ox * 0.9) *
                      Math.cos(time * 1.4 + oy * 0.7) *
                      Math.sin(time * 1.0 + oz * 0.5) * 0.35;
                      
        const scale = 1 + noise * (0.12 + scrollProgress * 0.25);
        pos[i] = ox * scale;
        pos[i + 1] = oy * scale;
        pos[i + 2] = oz * scale;
        
        wirePos[i] = ox * scale * 1.012;
        wirePos[i + 1] = oy * scale * 1.012;
        wirePos[i + 2] = oz * scale * 1.012;
    }
    icoGeo.attributes.position.needsUpdate = true;
    wireGeo.attributes.position.needsUpdate = true;
}

// --- Main Animation Loop ---
const clock = new THREE.Clock();

function animate() {
    requestAnimationFrame(animate);
    const time = clock.getElapsedTime();

    // Morph the icosahedron geometries
    morphVertices(time);

    // Dynamic mesh rotations
    icoMesh.rotation.y = time * 0.12 + scrollProgress * Math.PI * 2.5;
    icoMesh.rotation.x = time * 0.08 + scrollProgress * Math.PI * 0.8;
    wireMesh.rotation.copy(icoMesh.rotation);

    // Smooth linear interpolation of custom material colors
    icoMat.color.lerp(targetIcoColor, 0.05);
    wireMat.color.lerp(targetWireColor, 0.05);
    wireMat.opacity = 0.06 + scrollProgress * 0.15;

    // Soft pulsating scale
    const breathe = 1 + Math.sin(time * 1.6) * 0.02;
    icoMesh.scale.set(breathe, breathe, breathe);
    wireMesh.scale.set(breathe, breathe, breathe);

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
// GSAP SCROLLTRIGGERS
// ═══════════════════════════════════════════════════════════
gsap.registerPlugin(ScrollTrigger);

// Hero entrance elements
gsap.from(".hero-content > *", {
    y: 50, opacity: 0, duration: 1, stagger: 0.12,
    ease: "power3.out", delay: 0.2
});

gsap.from(".hero-mockup-wrapper", {
    x: 80, opacity: 0, scale: 0.95, duration: 1.2,
    ease: "power3.out", delay: 0.5
});

// Bento grid cards stagger
gsap.utils.toArray('.bento-card').forEach((card, i) => {
    gsap.from(card, {
        scrollTrigger: { trigger: card, start: "top 88%", once: true },
        y: 45, opacity: 0, duration: 0.65,
        delay: (i % 3) * 0.12, ease: "power2.out"
    });
});

// Changelog cards slide-in
gsap.utils.toArray('.changelog-item').forEach((item) => {
    ScrollTrigger.create({
        trigger: item,
        start: "top 82%",
        once: true,
        onEnter: () => item.classList.add('visible'),
    });
});

// Security section bento
gsap.from('.security-card', {
    scrollTrigger: { trigger: '.security-card', start: "top 78%", once: true },
    y: 50, opacity: 0, duration: 0.8, ease: "power2.out"
});

// Download panel animation
gsap.from('.final-block', {
    scrollTrigger: { trigger: '.final-block', start: "top 82%", once: true },
    y: 60, opacity: 0, scale: 0.97, duration: 0.9, ease: "power3.out"
});

// ═══════════════════════════════════════════════════════════
// INTERACTIVE UI ELEMENTS
// ═══════════════════════════════════════════════════════════

// Mockup Play/Pause button interaction
const mockupPlayBtn = document.getElementById('mockupPlayBtn');
const visualizerWaves = document.querySelector('.visualizer-waves');
let isMockupPlaying = false;
// Streaming a high-quality sample track locally for testing
const audioFile = new Audio('song.mp3');
audioFile.loop = true;
audioFile.volume = 0.5;

if (mockupPlayBtn && visualizerWaves) {
    // Initial state: stop animation
    visualizerWaves.style.display = 'none';

    mockupPlayBtn.addEventListener('click', () => {
        isMockupPlaying = !isMockupPlaying;
        if (isMockupPlaying) {
            mockupPlayBtn.textContent = '⏸';
            mockupPlayBtn.style.background = '#8A2BE2';
            mockupPlayBtn.style.boxShadow = '0 5px 15px rgba(138, 43, 226, 0.4)';
            visualizerWaves.style.display = 'flex';
            // Increase 3D particle activity
            particlesMat.color.setHex(0xFF5F38);
            audioFile.play().catch(err => {
                console.log("Audio playback failed due to user gesture interaction block: ", err);
            });
        } else {
            mockupPlayBtn.textContent = '▶';
            mockupPlayBtn.style.background = '#FF5F38';
            mockupPlayBtn.style.boxShadow = '0 5px 15px rgba(255, 95, 56, 0.4)';
            visualizerWaves.style.display = 'none';
            particlesMat.color.setHex(0x00F0FF);
            audioFile.pause();
        }
    });
}

// Interactive Audio Sandbox logic
const sandboxToggles = document.querySelectorAll('.sandbox-toggle');
const freqMesh = document.getElementById('freqMesh');
const visualizerTag = document.getElementById('visualizerTag');

if (sandboxToggles && freqMesh && visualizerTag) {
    sandboxToggles.forEach(btn => {
        btn.addEventListener('click', () => {
            // Remove active classes
            sandboxToggles.forEach(b => b.classList.remove('active'));
            // Add active to current
            btn.classList.add('active');

            const effect = btn.dataset.effect;
            
            // Clear prior effect classes on mesh
            freqMesh.className = 'freq-mesh';
            
            // Reset randomized heights
            const bars = freqMesh.querySelectorAll('span');

            if (effect === 'normal') {
                visualizerTag.textContent = 'NORMAL STEREO MODE';
                targetIcoColor.setHex(0xFF5F38); // Coral
                targetWireColor.setHex(0x8A2BE2); // Purple
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
            } 
            else if (effect === 'bass') {
                freqMesh.classList.add('bass');
                visualizerTag.textContent = 'BASS BOOST ACTIVE (+12DB SUB-BOOST)';
                targetIcoColor.setHex(0x39FF14); // Neon green
                targetWireColor.setHex(0x00F0FF); // Cyan
                // Bass frequencies (first few bars) pushed to maximum
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
            } 
            else if (effect === 'orbit') {
                freqMesh.classList.add('orbit');
                visualizerTag.textContent = '8D SPATIAL ORBIT IN COMSOS SPACE';
                targetIcoColor.setHex(0x00F0FF); // Cyan
                targetWireColor.setHex(0x8A2BE2); // Purple
                // Panning setup
                bars.forEach((bar, idx) => {
                    bar.style.setProperty('--h', `${40 + Math.sin(idx * 0.7) * 35}%`);
                });
            } 
            else if (effect === 'vocal') {
                freqMesh.classList.add('vocal');
                visualizerTag.textContent = 'VOCAL FORWARD (CLEAR HIGHS & MIDRANGE)';
                targetIcoColor.setHex(0x8A2BE2); // Purple
                targetWireColor.setHex(0xFF5F38); // Coral
                // Mid frequencies (middle bars) maximized
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

// 3D Tilt Cards Effect
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

// Magnetic Buttons Hover Effect
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
