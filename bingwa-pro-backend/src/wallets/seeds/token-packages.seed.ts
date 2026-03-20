// bingwa-pro-backend/src/wallets/seeds/token-packages.seed.ts
export const tokenPackages = [
  {
    name: 'Daily Trial',
    tokens: 50,
    price: 20, // KES 0.40 per token
    validityDays: 1,
    description: 'Perfect for testing the platform',
    features: ['Express Mode', 'Basic Support'],
    sortOrder: 1,
  },
  {
    name: 'Weekly Starter',
    tokens: 500,
    price: 150, // KES 0.30 per token
    validityDays: 7,
    description: 'Ideal for part-time agents',
    features: ['Express Mode', 'Advanced Mode', 'Priority Support'],
    sortOrder: 2,
  },
  {
    name: 'Monthly Business',
    tokens: 2500,
    price: 500, // KES 0.20 per token
    validityDays: 30,
    description: 'For full-time agents',
    features: ['Express Mode', 'Advanced Mode', 'Priority Support', 'Analytics'],
    sortOrder: 3,
  },
  {
    name: 'Bulk Trader',
    tokens: 10000,
    price: 1500, // KES 0.15 per token
    validityDays: 30,
    description: 'For high-volume agents',
    features: ['Express Mode', 'Advanced Mode', 'VIP Support', 'Analytics', 'Bulk Discounts'],
    sortOrder: 4,
  },
];