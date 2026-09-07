---
name: frontend-react
description: Build React and Next.js frontend code — component design (server vs client components, compound components, custom hooks), Next.js App Router patterns (data fetching, streaming/Suspense, metadata/SEO), CSS/Tailwind design systems, accessibility (a11y), and bundle optimization. Use this skill whenever the user is building a React or Next.js component or page, optimizing Core Web Vitals or bundle size, implementing responsive or accessible UI, setting up a frontend project, or asks how to structure a frontend codebase.
---

# Frontend (React & Next.js)

## Server vs Client Components (Next.js)

**Default to Server Components.** Add `'use client'` only when you need:
- Event handlers (`onClick`, `onChange`)
- State (`useState`, `useReducer`)
- Effects (`useEffect`)
- Browser APIs (`window`, `localStorage`, `document`)

```tsx
// Server Component (default) — no 'use client'
async function ProductPage({ params }: { params: { id: string } }) {
  const product = await getProduct(params.id);   // server-side fetch, no client waterfall
  return (
    <div>
      <h1>{product.name}</h1>
      <AddToCartButton productId={product.id} />   // client island
    </div>
  );
}

// Client Component
'use client';
function AddToCartButton({ productId }: { productId: string }) {
  const [adding, setAdding] = useState(false);
  return (
    <button
      onClick={async () => {
        setAdding(true);
        await addToCart(productId);
        setAdding(false);
      }}
      disabled={adding}
    >
      {adding ? 'Adding...' : 'Add to Cart'}
    </button>
  );
}
```

## Data fetching & streaming

**Parallel, not waterfall:**
```tsx
async function Dashboard() {
  const [user, stats, notifications] = await Promise.all([
    getUser(),
    getStats(),
    getNotifications(),
  ]);
  return <div>{/* ... */}</div>;
}
```

**Stream with Suspense** so the fast parts paint first:
```tsx
async function ProductPage({ params }: { params: { id: string } }) {
  return (
    <div>
      <ProductDetails id={params.id} />   {/* loads first */}
      <Suspense fallback={<ReviewsSkeleton />}>
        <Reviews productId={params.id} />  {/* streams in */}
      </Suspense>
    </div>
  );
}
```

## Component patterns

**Compound components — share state between related parts:**
```tsx
const Tabs = ({ children, defaultTab = 0 }) => {
  const [active, setActive] = useState(defaultTab);
  return (
    <TabsContext.Provider value={{ active, setActive }}>
      {children}
    </TabsContext.Provider>
  );
};
Tabs.List = TabList;
Tabs.Tab = Tab;
Tabs.Panel = TabPanel;

// <Tabs><Tabs.List><Tabs.Tab>Overview</Tabs.Tab></Tabs.List><Tabs.Panel>...</Tabs.Panel></Tabs>
```

**Custom hooks — extract reusable logic:**
```tsx
function useDebounce<T>(value: T, delay = 500): T {
  const [debounced, setDebounced] = useState(value);
  useEffect(() => {
    const t = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(t);
  }, [value, delay]);
  return debounced;
}
```

**Generic components with TypeScript:**
```tsx
interface ListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  keyExtractor: (item: T) => string;
  emptyState?: React.ReactNode;
}
function List<T>({ items, renderItem, keyExtractor, emptyState }: ListProps<T>) {
  if (items.length === 0) return <>{emptyState}</>;
  return (
    <ul>{items.map((item, i) => <li key={keyExtractor(item)}>{renderItem(item, i)}</li>)}</ul>
  );
}
```

## CSS / Tailwind design system

**Conditional classes with a `cn()` helper (clsx + tailwind-merge):**
```tsx
<button className={cn(
  'inline-flex items-center justify-center rounded-md font-medium transition-colors',
  size === 'sm' && 'h-8 px-3 text-xs',
  variant === 'primary' && 'bg-blue-600 text-white hover:bg-blue-700',
  disabled && 'pointer-events-none opacity-50'
)} />
```

**CSS variables for theming:**
```css
:root {
  --color-primary: #3B82F6;
  --color-surface: #FFFFFF;
  --color-text: #1F2937;
  --spacing-base: 0.25rem;
  --radius-base: 0.375rem;
}
```

**Fluid type scale:**
```css
--font-sm:   clamp(0.875rem, 0.8rem + 0.375vw, 1rem);
--font-base: clamp(1rem, 0.9rem + 0.5vw, 1.125rem);
--font-lg:   clamp(1.125rem, 1rem + 0.625vw, 1.25rem);
```

## Accessibility checklist

- [ ] Semantic HTML: `<button>`, `<nav>`, `<main>`, `<article>`, `<section>`
- [ ] Keyboard navigation: all interactive elements reachable and operable by keyboard
- [ ] ARIA labels for icons and complex widgets
- [ ] Color contrast: ≥ 4.5:1 normal text, ≥ 3:1 large text
- [ ] Visible, high-contrast focus rings
- [ ] Skip links ("Skip to main content")
- [ ] Meaningful alt text on all images
- [ ] Every input has an associated `<label>`

```tsx
// Accessible icon button
<button type="button" aria-label="Close dialog" onClick={onClose}
  className="focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:outline-none rounded">
  <XIcon aria-hidden="true" />
</button>

// Skip link
<a href="#main-content" className="sr-only focus:not-sr-only focus:fixed focus:top-4 focus:left-4">
  Skip to main content
</a>
```

## SEO / metadata (Next.js)

```tsx
// app/layout.tsx — root metadata
export const metadata: Metadata = {
  title: { template: '%s | My App', default: 'My App' },
  description: 'Application description',
  openGraph: {
    type: 'website',
    url: 'https://example.com',
    images: [{ url: '/og-image.png', width: 1200, height: 630 }],
  },
};

// Per-page
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const product = await getProduct(params.id);
  return { title: product.name, description: product.description };
}
```

## Bundle optimization

**Lazy-load heavy dependencies:**
```js
// next.config.js
const nextConfig = {
  experimental: {
    optimizePackageImports: ['lucide-react', '@heroicons/react'],
  },
};
```

**Swap heavy dependencies for lighter equivalents:**

| Package | Size | Alternative |
|---------|------|-------------|
| moment | 290 KB | date-fns (12 KB) or dayjs (2 KB) |
| lodash | 71 KB | lodash-es with tree-shaking, or native |
| axios | 14 KB | native `fetch` or ky (3 KB) |
| jquery | 87 KB | native DOM APIs |
| @mui/material | large | shadcn/ui or Radix UI |

**Rules of thumb:**
- Dynamic-import anything only used on a single route.
- Audit bundle size after every major dependency add (`next build` output or `webpack-bundle-analyzer`).
- Prefer CSS-in-JS-free (Tailwind) over heavy runtime styling for performance.

## Core Web Vitals — what to watch

| Metric | Good | Target |
|--------|------|--------|
| LCP (Largest Contentful Paint) | ≤ 2.5 s | < 2 s |
| CLS (Cumulative Layout Shift) | ≤ 0.1 | < 0.05 |
| INP (Interaction to Next Paint) | ≤ 200 ms | < 150 ms |

Common fixes: preconnect to critical origins, size images explicitly (avoid CLS), avoid client-side rehydration of large data, split JS with code-splitting.
