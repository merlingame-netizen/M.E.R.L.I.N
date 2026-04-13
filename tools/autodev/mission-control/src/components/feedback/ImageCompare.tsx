import { useState } from 'react';

interface ImageCompareProps {
  urls: [string, string];
  labels: [string, string];
  selected: string | null;
  onSelect: (label: string) => void;
}

export function ImageCompare({ urls, labels, selected, onSelect }: ImageCompareProps) {
  const [errors, setErrors] = useState<[boolean, boolean]>([false, false]);

  return (
    <div className="image-compare">
      {([0, 1] as const).map(i => (
        <button
          key={labels[i]}
          className={`image-compare__item ${selected === labels[i] ? 'image-compare__item--selected' : ''}`}
          onClick={() => onSelect(labels[i])}
          type="button"
        >
          {errors[i] ? (
            <div className="image-compare__placeholder">
              <span style={{ fontSize: '2em', opacity: 0.4 }}>&#128247;</span>
              <span style={{ opacity: 0.5, fontSize: '0.85em' }}>Screenshot not available</span>
            </div>
          ) : (
            <img
              src={urls[i]}
              alt={labels[i]}
              className="image-compare__img"
              onError={() => setErrors(prev => {
                const next: [boolean, boolean] = [...prev];
                next[i] = true;
                return next;
              })}
            />
          )}
          <span className="image-compare__label">{labels[i]}</span>
        </button>
      ))}
    </div>
  );
}
