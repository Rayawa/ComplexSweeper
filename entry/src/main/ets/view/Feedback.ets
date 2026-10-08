import { vibrator } from '@kit.SensorServiceKit';

/**
 * 轻振反馈。
 *
 * 长按开格如果没有任何触感反馈，手指会不确定自己到底按够时间没有 ——
 * 这个游戏里"按够没有"直接决定是标记还是开格，所以反馈很重要。
 *
 * 振动不在关键路径上：设备不支持、权限没给、调用失败，一律静默吞掉。
 */
export function feedback(durationMs: number): void {
  try {
    vibrator.startVibration(
      { type: 'time', duration: durationMs },
      { id: 0, usage: 'unknown' }
    ).catch(() => {
    });
  } catch (err) {
    // 没有振动能力也不影响游戏
  }
}

/** 单击：标记切换 */
export function feedbackTick(): void {
  feedback(10);
}

/** 长按：开格 */
export function feedbackReveal(): void {
  feedback(24);
}

/** 踩雷或通关 */
export function feedbackOutcome(): void {
  feedback(60);
}
