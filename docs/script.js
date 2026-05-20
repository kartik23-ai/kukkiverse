// ═══════════════════════════════════════════════════════════
// ROTTY MUSIC — WEBSITE ENGINE v3.0
// Three.js morphing icosahedron + GSAP ScrollTrigger
// ═══════════════════════════════════════════════════════════

// --- Three.js Setup ---
const canvas = document.getElementById('bg-canvas');
const scene = new THREE.Scene();
scene.fog = new THREE.FogExp2(0x030305, 0.025);

const camera = new THREE.PerspectiveCamera(55, window.innerWidth / window.innerHeight, 0.1, 1000);
const renderer = new THREE.WebGLRenderer({
    canvas, alpha: true, antialias: true, powerPreference: "high-performance"
});
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
camera.position.z = 20;

// --- Main 3D Object: Morphing Icosahedron with Wireframe ---
const icoGeo = new THREE.IcosahedronGeometry(5, 4);
const originalPositions = icoGeo.attributes.position.array.slice();

const icoMat = new THREE.MeshPhysicalMaterial({
    color: 0x7B61FF,
    emissive: 0x110022,
    roughness: 0.15,
    metalness: 0.85,
    clearcoat: 1.0,
    clearcoatRoughness: 0.05,
    transmission: 0.3,
    thickness: 1.5,
    wireframe: false,
});

const icoMesh = new THREE.Mesh(icoGeo, icoMat);
scene.add(icoMesh);

// Wireframe overlay
const wireGeo = new THREE.IcosahedronGeometry(5.05, 4);
const wireMat = new THREE.MeshBasicMaterial({
    color: 0xFA2D48,
    wireframe: true,
    transparent: true,
    opacity: 0.08,
});
const wireMesh = new THREE.Mesh(wireGeo, wireMat);
scene.add(wireMesh);

// --- Floating Particles ---
const particlesCount = 600;
const particlesGeo = new THREE.BufferGeometry();
const particlesPos = new Float32Array(particlesCount * 3);
for (let i = 0; i < particlesCount; i++) {
    particlesPos[i * 3] = (Math.random() - 0.5) * 80;
    particlesPos[i * 3 + 1] = (Math.random() - 0.5) * 80;
    particlesPos[i * 3 + 2] = (Math.random() - 0.5) * 80;
}
particlesGeo.setAttribute('position', new THREE.BufferAttribute(particlesPos, 3));
const particlesMat = new THREE.PointsMaterial({
    color: 0x7B61FF,
    size: 0.08,
    transparent: true,
    opacity: 0.5,
    sizeAttenuation: true,
});
const particles = new THREE.Points(particlesGeo, particlesMat);
scene.add(particles);

// --- Lighting ---
scene.add(new THREE.AmbientLight(0xffffff, 0.4));

const light1 = new THREE.DirectionalLight(0x7B61FF, 4);
light1.position.set(10, 10, 5);
scene.add(light1);

const light2 = new THREE.DirectionalLight(0xFA2D48, 4);
light2.position.set(-10, -8, 5);
scene.add(light2);

const light3 = new THREE.PointLight(0x06B6D4, 5, 50);
light3.position.set(0, 5, -10);
scene.add(light3);

// --- Mouse Tracking ---
let mouseX = 0, mouseY = 0;
const cursorGlow = document.getElementById('cursorGlow');

document.addEventListener('mousemove', (e) => {
    mouseX = (e.clientX - window.innerWidth / 2) * 0.003;
    mouseY = (e.clientY - window.innerHeight / 2) * 0.003;
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

// --- Scroll Tracking ---
let scrollProgress = 0;
window.addEventListener('scroll', () => {
    const maxScroll = document.body.scrollHeight - window.innerHeight;
    scrollProgress = Math.max(0, Math.min(1, window.scrollY / maxScroll));

    // Navbar style on scroll
    const nav = document.getElementById('navbar');
    if (nav) nav.classList.toggle('scrolled', window.scrollY > 80);
});

// --- Vertex Morphing ---
function morphVertices(time) {
    const pos = icoGeo.attributes.position.array;
    const wirePos = wireGeo.attributes.position.array;
    for (let i = 0; i < pos.length; i += 3) {
        const ox = originalPositions[i];
        const oy = originalPositions[i + 1];
        const oz = originalPositions[i + 2];
        const dist = Math.sqrt(ox * ox + oy * oy + oz * oz);
        const noise = Math.sin(time * 1.5 + ox * 0.8) *
                      Math.cos(time * 1.2 + oy * 0.6) *
                      Math.sin(time * 0.8 + oz * 0.4) * 0.4;
        const scale = 1 + noise * (0.15 + scrollProgress * 0.2);
        pos[i] = ox * scale;
        pos[i + 1] = oy * scale;
        pos[i + 2] = oz * scale;
        wirePos[i] = ox * scale * 1.01;
        wirePos[i + 1] = oy * scale * 1.01;
        wirePos[i + 2] = oz * scale * 1.01;
    }
    icoGeo.attributes.position.needsUpdate = true;
    wireGeo.attributes.position.needsUpdate = true;
}

// --- Animation Loop ---
const clock = new THREE.Clock();

function animate() {
    requestAnimationFrame(animate);
    const time = clock.getElapsedTime();

    // Morph vertices
    morphVertices(time);

    // Rotation
    icoMesh.rotation.y = time * 0.15 + scrollProgress * Math.PI * 3;
    icoMesh.rotation.x = time * 0.1 + scrollProgress * Math.PI;
    wireMesh.rotation.copy(icoMesh.rotation);

    // Color shift on scroll
    const c1 = new THREE.Color(0x7B61FF);
    const c2 = new THREE.Color(0xFA2D48);
    const c3 = new THREE.Color(0x06B6D4);
    icoMat.color.copy(c1).lerp(c2, scrollProgress);
    wireMat.color.copy(c2).lerp(c3, scrollProgress);
    wireMat.opacity = 0.06 + scrollProgress * 0.12;

    // Breathing
    const breathe = 1 + Math.sin(time * 1.5) * 0.015;
    icoMesh.scale.set(breathe, breathe, breathe);
    wireMesh.scale.set(breathe, breathe, breathe);

    // Particles rotation
    particles.rotation.y = time * 0.02;
    particles.rotation.x = time * 0.01;

    // Camera
    camera.position.x += (mouseX * 5 - camera.position.x) * 0.04;
    camera.position.y += (-mouseY * 3 - scrollProgress * 10 - camera.position.y) * 0.04;
    camera.lookAt(scene.position);

    renderer.render(scene, camera);
}

// --- Resize ---
window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
});

animate();

// ═══ GSAP Animations ═══
gsap.registerPlugin(ScrollTrigger);

// Hero entrance
gsap.from(".hero-content > *", {
    y: 60, opacity: 0, duration: 1.2, stagger: 0.15,
    ease: "power3.out", delay: 0.3
});

gsap.from(".stats-row .stat", {
    y: 40, opacity: 0, duration: 0.8, stagger: 0.15,
    ease: "power2.out", delay: 1.2
});

// Bento cards
gsap.utils.toArray('.bento-card').forEach((card, i) => {
    gsap.from(card, {
        scrollTrigger: { trigger: card, start: "top 85%", once: true },
        y: 50, opacity: 0, duration: 0.7,
        delay: i * 0.1, ease: "power2.out"
    });
});

// Changelog items
gsap.utils.toArray('.changelog-item').forEach((item, i) => {
    ScrollTrigger.create({
        trigger: item,
        start: "top 80%",
        once: true,
        onEnter: () => item.classList.add('visible'),
    });
});

// Security card
gsap.from('.security-card', {
    scrollTrigger: { trigger: '.security-card', start: "top 75%", once: true },
    y: 60, opacity: 0, duration: 0.8, ease: "power2.out"
});

// Final CTA
gsap.from('.final-block', {
    scrollTrigger: { trigger: '.final-block', start: "top 80%", once: true },
    y: 80, opacity: 0, scale: 0.95, duration: 1, ease: "power3.out"
});

// ═══ Stat Counter Animation ═══
const statNums = document.querySelectorAll('.stat-num');
const observerOptions = { threshold: 0.5 };
const statObserver = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
        if (entry.isIntersecting) {
            const el = entry.target;
            const target = parseInt(el.dataset.target, 10);
            let current = 0;
            const step = target / 60;
            const timer = setInterval(() => {
                current += step;
                if (current >= target) { current = target; clearInterval(timer); }
                el.textContent = Math.round(current);
            }, 16);
            statObserver.unobserve(el);
        }
    });
}, observerOptions);
statNums.forEach(n => statObserver.observe(n));

// ═══ UI Interactions ═══

// Magnetic Buttons
document.querySelectorAll('.magnetic').forEach(btn => {
    btn.addEventListener('mousemove', (e) => {
        const rect = btn.getBoundingClientRect();
        const x = e.clientX - rect.left - rect.width / 2;
        const y = e.clientY - rect.top - rect.height / 2;
        gsap.to(btn, { x: x * 0.35, y: y * 0.35, duration: 0.4, ease: "power2.out" });
    });
    btn.addEventListener('mouseleave', () => {
        gsap.to(btn, { x: 0, y: 0, duration: 0.7, ease: "elastic.out(1, 0.3)" });
    });
});

// 3D Tilt Cards
document.querySelectorAll('.tilt-card').forEach(card => {
    card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = ((e.clientX - rect.left) / rect.width - 0.5) * 12;
        const y = ((e.clientY - rect.top) / rect.height - 0.5) * -12;
        card.style.transform = `perspective(1000px) rotateX(${y}deg) rotateY(${x}deg) translateZ(10px)`;
    });
    card.addEventListener('mouseleave', () => {
        card.style.transform = `perspective(1000px) rotateX(0deg) rotateY(0deg) translateZ(0px)`;
    });
});
