import { expect, test } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.goto("/");
});

test("播放页默认只显示一行动态歌词，点击后进入完整歌词", async ({ page }) => {
  const currentLyric = page.getByTestId("current-lyric");

  await expect(currentLyric).toBeVisible();
  await expect(page.getByTestId("full-lyrics-screen")).toHaveCount(0);
  await currentLyric.click();

  const fullLyrics = page.getByTestId("full-lyrics-screen");
  await expect(fullLyrics).toBeVisible();
  await expect(fullLyrics.getByText("别总是为难自己", { exact: true })).toBeVisible();
  await expect(fullLyrics.getByText("你说爱是一种放任", { exact: true })).toBeVisible();

  await page.getByRole("button", { name: "返回播放页" }).click();
  await expect(currentLyric).toBeVisible();
});

test("播放进度条有明确轨道和填充，并可拖动", async ({ page }) => {
  const slider = page.getByTestId("progress-slider");
  const track = page.getByTestId("progress-track");
  const fill = page.getByTestId("progress-fill");

  await expect(track).toBeVisible();
  await expect(fill).toBeVisible();
  await slider.fill("138");
  await expect(slider).toHaveValue("138");
  await expect(fill).toHaveAttribute("style", /50%/);
});
