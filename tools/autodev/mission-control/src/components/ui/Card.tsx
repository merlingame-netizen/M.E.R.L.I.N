import type { ReactNode } from 'react';
import { motion } from 'framer-motion';

interface CardProps {
  children: ReactNode;
  className?: string;
  delay?: number;
  hoverable?: boolean;
}

export function Card({ children, className, delay = 0, hoverable = false }: CardProps) {
  return (
    <motion.div
      className={`glass-panel${hoverable ? ' glass-panel--hoverable' : ''}${className ? ` ${className}` : ''}`}
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay, duration: 0.3, ease: [0.4, 0, 0.2, 1] }}
    >
      {children}
    </motion.div>
  );
}
