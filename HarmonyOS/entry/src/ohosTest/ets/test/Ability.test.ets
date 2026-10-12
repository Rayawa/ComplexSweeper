import { describe, beforeAll, beforeEach, it, expect } from '@ohos/hypium';
import { Driver, ON, MatchPattern, abilityDelegatorRegistry } from '@kit.TestKit';

export default function abilityTest() {
  describe('ModeInteractionTest', () => {
    let driver: Driver = Driver.create();
    const settle = async (): Promise<void> => { await driver.waitForIdle(300, 5000); };
    const clickCell = async (row: number, col: number, long: boolean = false): Promise<void> => {
      const center = await (await driver.findComponent(ON.id(`cell-${row}-${col}`))).getBoundsCenter();
      if (long) { await driver.longClick(center.x, center.y); }
      else { await driver.click(center.x, center.y); }
      await settle();
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

    it('longPressFlagProtectionAndFlagCycle', 0, async () => {
      await (await driver.findComponent(ON.text('闵可夫斯基').clickable(true))).click();
      await settle();
      const expected: string[] = ['+1', '-1', '+j', '-j', '未翻开'];
      for (const label of expected) {
        await clickCell(0, 0, false);
        expect(await (await driver.findComponent(ON.id('cell-0-0'))).getDescription()).assertContain(label);
        if (label === '+1') {
          await clickCell(0, 0, true);
          expect(await (await driver.findComponent(ON.id('status'))).getText()).assertContain('长按翻开第一格');
        }
      }
      await clickCell(0, 0, true);
      expect(await (await driver.findComponent(ON.id('status'))).getText()).assertContain('单击标记');
      expect(await (await driver.findComponent(ON.id('cell-0-0'))).getDescription()).assertContain('空白');
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
    it('aboutCloseAndCreditAlignment', 0, async () => {
      await (await driver.findComponent(ON.type('Button').text('').clickable(true))).click();
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
