import { test, expect } from '@playwright/test';

test.describe('冒険者ギルド - 基本画面表示', () => {

  test('アプリ起動時にメイン画面が表示される', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // タイトルまたは主要UI要素が表示されていることを確認
    // Flutter webはcanvasベースのため、DOM要素ではなくcanvasの存在を確認
    const flutterView = page.locator('flutter-view');
    await expect(flutterView).toBeAttached({ timeout: 30000 });
  });

  test('ページが読み込まれ、エラーなくレンダリングされる', async ({ page }) => {
    const errors: string[] = [];
    page.on('pageerror', (err) => errors.push(err.message));

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    expect(errors).toEqual([]);
  });

  test('アプリのタイトルが正しい', async ({ page }) => {
    await page.goto('/');
    const title = await page.title();
    expect(title).toContain('rpg_todo');
  });
});

test.describe('ナビゲーションと画面遷移', () => {

  test('初期画面が表示されてから応答がある', async ({ page }) => {
    const response = await page.goto('/');
    expect(response?.status()).toBe(200);
  });

  test('service workerが登録される（PWA対応確認）', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // PWAのservice worker登録を確認
    const swUrl = await page.evaluate(async () => {
      if ('serviceWorker' in navigator) {
        const registrations = await navigator.serviceWorker.getRegistrations();
        return registrations.length > 0;
      }
      return null;
    });

    if (swUrl !== null) {
      expect(swUrl).toBe(true);
    }
  });
});
