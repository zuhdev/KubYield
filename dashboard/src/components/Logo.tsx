export function Logo() {
  return (
    <a className="brand" href="#top" aria-label="KubYield home">
      <svg
        className="brand__mark"
        viewBox="0 0 40 40"
        fill="none"
        aria-hidden="true"
      >
        <rect width="40" height="40" rx="11" fill="currentColor" />
        <path
          d="M10.5 9.5h4.7v8.7h9.6V9.5h4.7v21h-4.7v-7.8h-9.6v7.8h-4.7v-21Z"
          fill="#07110a"
        />
        <circle cx="30.2" cy="10.2" r="2.6" fill="#07110a" opacity=".55" />
      </svg>
      <span className="brand__word">KubYield</span>
      <span className="brand__beta">beta</span>
    </a>
  );
}
