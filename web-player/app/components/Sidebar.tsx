'use client';

import { Home, Music2, Search, Flame, Sliders, Smartphone, Radio, Compass } from 'lucide-react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

export default function Sidebar() {
    const pathname = usePathname();

    return (
        <aside className="w-72 flex-col gap-6 p-6 hidden md:flex h-screen sticky top-0 border-r border-white/10 bg-black/40 backdrop-blur-3xl z-50 shadow-2xl selection:bg-purple-500">
            {/* Logo */}
            <div className="flex items-center gap-3 px-2 pt-2">
                <div className="w-10 h-10 rounded-2xl bg-gradient-to-tr from-purple-600 via-indigo-500 to-cyan-400 p-0.5 shadow-xl shadow-purple-500/30 flex items-center justify-center animate-pulse">
                    <div className="w-full h-full bg-black/80 rounded-[14px] flex items-center justify-center">
                        <Music2 className="text-purple-400 w-5 h-5" />
                    </div>
                </div>
                <div>
                    <span className="font-extrabold text-xl tracking-tight text-white block leading-none">ROTTY MUSIC</span>
                    <span className="text-[10px] font-bold tracking-widest text-purple-400 uppercase">VX WEB PLAYER</span>
                </div>
            </div>

            {/* Navigation Links */}
            <div className="space-y-1.5 pt-4">
                <p className="px-4 text-[10px] font-bold tracking-widest text-white/40 uppercase mb-2">MENU</p>
                <NavItem href="/" icon={<Home size={20} />} label="Home" active={pathname === '/'} />
                <NavItem href="/search" icon={<Search size={20} />} label="Search Songs & Artists" active={pathname === '/search'} />
                <NavItem href="/#trending" icon={<Flame size={20} />} label="Top Hits & Trending" active={false} />
                <NavItem href="/#discover" icon={<Compass size={20} />} label="Discover" active={false} />
            </div>

            {/* Engine Status */}
            <div className="mt-auto space-y-4">
                <div className="p-4 rounded-2xl bg-gradient-to-br from-purple-900/40 via-indigo-900/30 to-black/60 border border-purple-500/30 shadow-xl backdrop-blur-md">
                    <div className="flex items-center gap-2 mb-2">
                        <Radio size={16} className="text-emerald-400 animate-pulse" />
                        <span className="text-xs font-bold text-white">Dual Engine Active</span>
                    </div>
                    <p className="text-xs text-gray-400 leading-relaxed mb-3">Powered by JioSaavn HD API & Hugging Face backend.</p>
                    <a
                        href="https://kartik23-ai.github.io/kukkiverse/app-release.apk"
                        target="_blank"
                        className="w-full py-2.5 bg-gradient-to-r from-purple-500 to-indigo-600 hover:from-purple-600 hover:to-indigo-700 text-white font-bold text-xs rounded-xl flex items-center justify-center gap-2 shadow-lg shadow-purple-500/20 transition-all hover:scale-[1.02] active:scale-95"
                    >
                        <Smartphone size={14} /> Download Mobile App
                    </a>
                </div>
            </div>
        </aside>
    );
}

function NavItem({ href, icon, label, active }: { href: string; icon: React.ReactNode; label: string; active: boolean }) {
    return (
        <Link
            href={href}
            className={`flex items-center gap-3.5 px-4 py-3 rounded-xl transition-all duration-300 font-semibold text-sm ${
                active
                    ? 'bg-gradient-to-r from-purple-500/20 to-indigo-500/10 text-white border border-purple-500/30 shadow-lg shadow-purple-500/10'
                    : 'text-gray-400 hover:text-white hover:bg-white/5'
            }`}
        >
            <div className={`${active ? 'text-purple-400' : 'text-gray-400'}`}>{icon}</div>
            <span>{label}</span>
        </Link>
    );
}
