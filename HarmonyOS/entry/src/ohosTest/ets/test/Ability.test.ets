import { describe, beforeAll, beforeEach, it, expect } from '@ohos/hypium';
import { Driver, ON, MatchPattern, abilityDelegatorRegistry } from '@kit.TestKit';

export default function abilityTest() {
  describe('ModeInteractionTest', () => {
    let driver: Driver = Driver.create();
    const settle = async (): Promise<void> => { await driver.waitForIdle(300, 5000); };
    const clickCell = async (row: number, col: number, long: boolean = false): Promise<void> => {
      // 模式切换会重建棋盘；UiTest 查询与读取坐标之间，旧组件可能失效。
      // 只重试尚未注入触摸的坐标查询，避免把一次点击执行两遍。
      for (let attempt: number = 0; attempt < 3; attempt++) {
        await settle();
        let x: number = 0;
        let y: number = 0;
        try {
          const target = await driver.waitForComponent(ON.id(`cell-${row}-${col}`), 5000);
          const center = await target.getBoundsCenter();
          x = center.x;
          y = center.y;
        } catch (err) {
          if (attempt === 2 || !String(err).includes('NoCandidates')) throw new Error(String(err));
          continue;
        }
        if (long) { await driver.longClick(x, y); }
        else { await driver.click(x, y); }
        await settle();
        return;
      }
    };
    beforeAll(async () => {
      await abilityDelegatorRegistry.getAbilityDelegator().startAbility({
        bundleName: 'top.rayawa.complexsweeper', abilityName: 'EntryAbility'
      });
      await driver.waitForComponent(ON.id('restart'), 10000);
      await settle();
    });
    beforeEach(async () => {
      await (await driver.findComponent(ON.text('圆复数').clickable(true))).click();
      await settle();
      await (await driver.findComponent(ON.text('初级'))).click();
      await settle();
      await (await driver.findComponent(ON.id('restart'))).click();
      await settle();
    });

    it('modeAndDifficultySelection', 0, async () => {
      await (await driver.findComponent(ON.text('中级'))).click();
      await settle();
      await (await driver.findComponent(ON.text('闵可夫斯基').clickable(true))).click();
      await settle();
      expect(await (await driver.findComponent(ON.id('counter-2'))).getDescription()).assertContain('+j');
      await driver.assertComponentExist(ON.id('cell-15-15'));
      for (let i: number = 0; i < 3; i++) {
        await clickCell(0, 0, false);
      }
      expect(await (await driver.findComponent(ON.id('cell-0-0'))).getDescription()).assertContain('旗帜 +j');
      await (await driver.findComponent(ON.text('闵可夫斯基').clickable(true))).click();
      await settle();
      await (await driver.findComponent(ON.text('中级'))).click();
      await settle();
      expect(await (await driver.findComponent(ON.id('cell-0-0'))).getDescription()).assertContain('旗帜 +j');
      await (await driver.findComponent(ON.id('restart'))).click();
      await settle();
      expect(await (await driver.findComponent(ON.id('counter-2'))).getDescription()).assertContain('+j');
      expect(await (await driver.findComponent(ON.id('cell-0-0'))).getDescription()).assertContain('未翻开');
      await (await driver.findComponent(ON.text('圆复数').clickable(true))).click();
      await settle();
      expect(await (await driver.findComponent(ON.id('counter-2'))).getDescription()).assertContain('+i');
      await driver.assertComponentExist(ON.id('cell-15-15'));
    });

    it('longPressClearsFlagAndStartsGame', 0, async () => {
      for (const mode of ['圆复数', '闵可夫斯基']) {
        await (await driver.findComponent(ON.text(mode).clickable(true))).click();
        await settle();
        const expected: string[] = mode === '圆复数' ? ['+1', '-1', '+i', '-i', '未翻开'] : ['+1', '-1', '+j', '-j', '未翻开'];
        for (const label of expected) {
          await clickCell(0, 0);
          expect(await (await driver.findComponent(ON.id('cell-0-0'))).getDescription()).assertContain(label);
        }
        for (let flag: number = 1; flag <= 4; flag++) {
          await (await driver.findComponent(ON.id('restart'))).click();
          await settle();
          for (let k: number = 0; k < flag; k++) await clickCell(0, 0);
          await clickCell(0, 1);
          await clickCell(0, 0, true);
          expect(await (await driver.findComponent(ON.id('status'))).getText()).assertContain('单击标记');
          expect(await (await driver.findComponent(ON.id('cell-0-0'))).getDescription()).assertContain('空白');
          expect(await (await driver.findComponent(ON.id('cell-0-1'))).getDescription()).assertContain('旗帜 +1');
        }
      }
    });

    it('counterRefreshAndTimerReset', 0, async () => {
      await (await driver.findComponent(ON.text('闵可夫斯基').clickable(true))).click();
      await settle();
      await clickCell(4, 4, true);
      const before: string = await (await driver.findComponent(ON.id('counter-0'))).getDescription();
      const remaining: number = Number(before.split(' ').pop());
      const hidden = await driver.findComponents(ON.description('未翻开', MatchPattern.CONTAINS));
      expect(hidden.length > 0).assertTrue();
      await hidden[0].click();
      await settle();
      const after: string = await (await driver.findComponent(ON.id('counter-0'))).getDescription();
      expect(Number(after.split(' ').pop())).assertEqual(remaining - 1);
      await (await driver.findComponent(ON.id('restart'))).click();
      await settle();
      expect(await (await driver.findComponent(ON.id('status'))).getText()).assertContain('长按翻开第一格');
      expect(await (await driver.findComponent(ON.id('counter-0'))).getDescription()).assertContain('开局后公布');
    });

    it('repeatedDifficultyChangesDoNotCrash', 0, async () => {
      await (await driver.findComponent(ON.text('闵可夫斯基').clickable(true))).click();
      await settle();
      for (let round: number = 0; round < 3; round++) {
        for (const index of [2, 0, 1, 2, 0]) {
          await (await driver.findComponent(ON.text(['初级', '中级', '高级'][index]))).click();
          await settle();
          await driver.assertComponentExist(ON.id('cell-0-0'));
          expect(await (await driver.findComponent(ON.id('counter-2'))).getDescription()).assertContain('+j');
        }
      }
    });
    it('appearanceSelectorStaysInTitleBar', 0, async () => {
      const appearance = await (await driver.findComponent(ON.id('appearance'))).getBoundsCenter();
      const about = await (await driver.findComponent(ON.id('about'))).getBoundsCenter();
      const difficulty = await (await driver.findComponent(ON.id('difficulty-selector'))).getBoundsCenter();
      expect(Math.abs(appearance.y - about.y) < 20).assertTrue();
      expect(appearance.y < difficulty.y).assertTrue();
    });

    it('appearanceSwitchKeepsFlagsAndCounters', 0, async () => {
      const original: string = await (await driver.findComponent(ON.id('appearance'))).getDescription();
      const next: string = original === '彩色' ? '黑白' : '彩色';
      await clickCell(0, 0);
      await clickCell(4, 4, true);
      const before: string = await (await driver.findComponent(ON.id('counter-0'))).getDescription();
      await (await driver.findComponent(ON.text(next))).click();
      await settle();
      expect(await (await driver.findComponent(ON.id('appearance'))).getDescription()).assertEqual(next);
      await (await driver.findComponent(ON.text(next))).click();
      await settle();
      expect(await (await driver.findComponent(ON.id('cell-0-0'))).getDescription()).assertContain('旗帜 +1');
      expect(await (await driver.findComponent(ON.id('cell-4-4'))).getDescription()).assertContain('空白');
      expect(await (await driver.findComponent(ON.id('status'))).getText()).assertContain('单击标记');
      expect(await (await driver.findComponent(ON.id('counter-0'))).getDescription()).assertEqual(before);
      await (await driver.findComponent(ON.text(original))).click();
      await settle();
      expect(await (await driver.findComponent(ON.id('appearance'))).getDescription()).assertEqual(original);
    });

    it('aboutCloseAndCreditAlignment', 0, async () => {
      await (await driver.findComponent(ON.id('about'))).click();
      await settle();
      const close = await (await driver.findComponent(ON.id('about-close'))).getBoundsCenter();
      const glyph = await (await driver.findComponent(ON.id('about-close-glyph'))).getBoundsCenter();
      expect(Math.abs(close.x - glyph.x) < 2 && Math.abs(close.y - glyph.y) < 2).assertTrue();
      await (await driver.findComponent(ON.id('tutorial-scroll'))).scrollToBottom();
      await settle();
      const link = await (await driver.findComponent(ON.id('original-repository'))).getBoundsCenter();
      const row = await (await driver.findComponent(ON.id('original-repository-row'))).getBoundsCenter();
      expect(Math.abs(link.x - row.x) < 2).assertTrue();
      await (await driver.findComponent(ON.id('about-close'))).click();
      await settle();
      await driver.assertComponentExist(ON.id('restart'));
    });
  });
}
