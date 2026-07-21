import React, { createContext, useContext, useState, useEffect } from 'react';
import { StorageService } from '../services/storage';

type ThemeMode = 'normal';

interface ThemeContextType {
  theme: ThemeMode;
  setTheme: (theme: ThemeMode) => void;
}

const ThemeContext = createContext<ThemeContextType | undefined>(undefined);

export const ThemeProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [theme, setThemeState] = useState<ThemeMode>('normal');

  useEffect(() => {
    const root = document.documentElement;
    root.style.setProperty('--accent', '#fa2d48');
    root.style.setProperty('--accent-soft', '#ff6482');
    root.style.setProperty('--accent-alt', '#5e5ce6');
    StorageService.setTheme('normal');
  }, []);

  const setTheme = (newTheme: ThemeMode) => {
    setThemeState(newTheme);
  };

  return (
    <ThemeContext.Provider value={{ theme, setTheme }}>
      {children}
    </ThemeContext.Provider>
  );
};

export const useTheme = () => {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
};
