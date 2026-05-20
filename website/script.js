// --- Three.js Setup ---
const canvas = document.getElementById('bg-canvas');
const scene = new THREE.Scene();
scene.fog = new THREE.FogExp2(0x030305, 0.03);

const camera = new THREE.PerspectiveCamera(60, window.innerWidth / window.innerHeight, 0.1, 1000);
const renderer = new THREE.WebGLRenderer({
    canvas: canvas,
    alpha: true,
    antialias: true,
    powerPreference: "high-performance"
});

renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
camera.position.z = 18;

// --- 3D Object: Sexy Liquid Metal / Glass Torus Knot ---
const geometry = new THREE.TorusKnotGeometry(4.5, 1.5, 256, 64);

// Premium physical material (looks like liquid glass/metal)
const material = new THREE.MeshPhysicalMaterial({
    color: 0xFA2D48,
    emissive: 0x110022,
    roughness: 0.1,
    metalness: 0.8,
    clearcoat: 1.0,
    clearcoatRoughness: 0.1,
    transmission: 0.5, // glass-like
    thickness: 1.0,
});

const fluidMesh = new THREE.Mesh(geometry, material);
scene.add(fluidMesh);

// --- Lighting (Crucial for physical materials) ---
const ambientLight = new THREE.AmbientLight(0xffffff, 0.5);
scene.add(ambientLight);

// Purple/Blue light from top right
const light1 = new THREE.DirectionalLight(0x7B61FF, 3);
light1.position.set(10, 10, 5);
scene.add(light1);

// Neon Red light from bottom left
const light2 = new THREE.DirectionalLight(0xFA2D48, 4);
light2.position.set(-10, -10, 5);
scene.add(light2);

// Bright Cyan accent light behind
const light3 = new THREE.PointLight(0x00D4FF, 5, 50);
light3.position.set(0, 0, -10);
scene.add(light3);


// --- Mouse / Touch Tracking ---
let mouseX = 0;
let mouseY = 0;
let targetX = 0;
let targetY = 0;

const windowHalfX = window.innerWidth / 2;
const windowHalfY = window.innerHeight / 2;

function onPointerMove(clientX, clientY) {
    mouseX = (clientX - windowHalfX) * 0.003;
    mouseY = (clientY - windowHalfY) * 0.003;
}

document.addEventListener('mousemove', (e) => onPointerMove(e.clientX, e.clientY));
document.addEventListener('touchmove', (e) => {
    if(e.touches.length > 0) onPointerMove(e.touches[0].clientX, e.touches[0].clientY);
}, { passive: true });

// --- Scroll Tracking ---
let scrollProgress = 0;
window.addEventListener('scroll', () => {
    const maxScroll = document.body.scrollHeight - window.innerHeight;
    scrollProgress = Math.max(0, Math.min(1, window.scrollY / maxScroll));
});

// --- Animation Loop ---
const clock = new THREE.Clock();

function animate() {
    requestAnimationFrame(animate);
    const time = clock.getElapsedTime();

    // Smooth, sexy rotation
    fluidMesh.rotation.y = time * 0.3 + (scrollProgress * Math.PI * 2);
    fluidMesh.rotation.x = time * 0.2 + (scrollProgress * Math.PI);
    fluidMesh.rotation.z = time * 0.1;

    // Pulse effect (breathing)
    const scale = 1 + Math.sin(time * 2) * 0.03;
    fluidMesh.scale.set(scale, scale, scale);

    // Color shifting based on scroll
    const colorStart = new THREE.Color(0xFA2D48); // Rotty Red
    const colorEnd = new THREE.Color(0x00D4FF);   // Rotty Blue
    material.color.lerpColors(colorStart, colorEnd, scrollProgress);

    // Camera parallax & scroll movement
    targetX = mouseX * 4;
    targetY = mouseY * 4;
    
    // As you scroll down, the object moves slightly up and background shifts
    const scrollY_cam = scrollProgress * -8;

    camera.position.x += (targetX - camera.position.x) * 0.05;
    camera.position.y += (scrollY_cam - targetY - camera.position.y) * 0.05;
    
    camera.lookAt(scene.position);

    renderer.render(scene, camera);
}

// --- Resize Handling ---
window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
});

animate();

// --- UI Interactions (Magnetic Buttons & Tilt Cards) ---
const magnetics = document.querySelectorAll('.magnetic');
magnetics.forEach(btn => {
    btn.addEventListener('mousemove', (e) => {
        const rect = btn.getBoundingClientRect();
        const h = rect.width / 2;
        const v = rect.height / 2;
        const x = e.clientX - rect.left - h;
        const y = e.clientY - rect.top - v;
        
        gsap.to(btn, { x: x * 0.4, y: y * 0.4, duration: 0.4, ease: "power2.out" });
        gsap.to(btn.querySelector('.btn-text'), { x: x * 0.2, y: y * 0.2, duration: 0.4, ease: "power2.out" });
    });

    btn.addEventListener('mouseleave', () => {
        gsap.to(btn, { x: 0, y: 0, duration: 0.7, ease: "elastic.out(1, 0.3)" });
        gsap.to(btn.querySelector('.btn-text'), { x: 0, y: 0, duration: 0.7, ease: "elastic.out(1, 0.3)" });
    });
});

const tiltCards = document.querySelectorAll('.tilt-card');
tiltCards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        const centerX = rect.width / 2;
        const centerY = rect.height / 2;
        
        const rotateX = ((y - centerY) / centerY) * -10;
        const rotateY = ((x - centerX) / centerX) * 10;
        
        card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg)`;
    });
    
    card.addEventListener('mouseleave', () => {
        card.style.transform = `perspective(1000px) rotateX(0deg) rotateY(0deg)`;
    });
});

gsap.from(".hero-content > *", { y: 50, opacity: 0, duration: 1, stagger: 0.2, ease: "power3.out", delay: 0.5 });
