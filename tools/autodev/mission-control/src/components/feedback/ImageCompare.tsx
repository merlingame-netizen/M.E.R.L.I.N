interface ImageCompareProps {
  urls: [string, string];
  labels: [string, string];
  selected: string | null;
  onSelect: (label: string) => void;
}

export function ImageCompare({ urls, labels, selected, onSelect }: ImageCompareProps) {
  return (
    <div className="image-compare">
      {([0, 1] as const).map(i => (
        <button
          key={labels[i]}
          className={`image-compare__item ${selected === labels[i] ? 'image-compare__item--selected' : ''}`}
          onClick={() => onSelect(labels[i])}
          type="button"
        >
          <img src={urls[i]} alt={labels[i]} className="image-compare__img" />
          <span className="image-compare__label">{labels[i]}</span>
        </button>
      ))}
    </div>
  );
}
