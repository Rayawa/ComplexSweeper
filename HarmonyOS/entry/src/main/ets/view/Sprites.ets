import { ACHIEVABLE, HYPER_ACHIEVABLE, MODE_COMPLEX, MODE_HYPER } from '../model/Complex';

/**
 * 贴图查表。
 *
 * 素材来自复扫雷项目的图集，已在 scripts/atlas/slice.ts 里切成单张 PNG。
 * $r() 只认字面量，所以这里只能老老实实写一长串 switch —— 这层存在的意义
 * 就是把"用哪个下标查哪张图"这件事收在一处，别散到各个组件里。
 *
 * 注意：其中经典扫雷原始图像（closed / blank / num_* / flag_* / mine_* /
 * boom_* / wrong_* / right_* / face_*）的版权属于 Microsoft，不在本项目
 * GPL-3.0 的授权范围内，只适合个人学习用途。详见 README。
 */

/** 数字贴图：按模式查询24个圆复数值或39个双曲有符号值 */
export function numSprite(clue: number, mode: number = MODE_COMPLEX): Resource {
  if (mode === MODE_HYPER) {
    return hyperNumSprite(clue);
  }
  switch (clue) {
    case 0:
      return $r('app.media.cw_num_0');
    case 1:
      return $r('app.media.cw_num_1');
    case 2:
      return $r('app.media.cw_num_2');
    case 4:
      return $r('app.media.cw_num_4');
    case 5:
      return $r('app.media.cw_num_5');
    case 8:
      return $r('app.media.cw_num_8');
    case 9:
      return $r('app.media.cw_num_9');
    case 10:
      return $r('app.media.cw_num_10');
    case 13:
      return $r('app.media.cw_num_13');
    case 16:
      return $r('app.media.cw_num_16');
    case 17:
      return $r('app.media.cw_num_17');
    case 18:
      return $r('app.media.cw_num_18');
    case 20:
      return $r('app.media.cw_num_20');
    case 25:
      return $r('app.media.cw_num_25');
    case 26:
      return $r('app.media.cw_num_26');
    case 29:
      return $r('app.media.cw_num_29');
    case 32:
      return $r('app.media.cw_num_32');
    case 34:
      return $r('app.media.cw_num_34');
    case 36:
      return $r('app.media.cw_num_36');
    case 37:
      return $r('app.media.cw_num_37');
    case 40:
      return $r('app.media.cw_num_40');
    case 49:
      return $r('app.media.cw_num_49');
    case 50:
      return $r('app.media.cw_num_50');
    default:
      return $r('app.media.cw_num_64');
  }
}

/** 数字贴图是否存在。不存在的值只能画成空白。 */
export function hasNumSprite(clue: number, mode: number = MODE_COMPLEX): boolean {
  return (mode === MODE_HYPER ? HYPER_ACHIEVABLE : ACHIEVABLE).indexOf(clue) >= 0;
}

/** 插着的旗，按玩家插的那一型取图（1=+1 2=-1 3=+i 4=-i） */
export function flagSprite(t: number, mode: number = MODE_COMPLEX): Resource {
  if (mode === MODE_HYPER && (t === 3 || t === 4)) {
    return t === 3 ? $r('app.media.cw_hflag_3') : $r('app.media.cw_hflag_4');
  }
  switch (t) {
    case 1:
      return $r('app.media.cw_flag_1');
    case 2:
      return $r('app.media.cw_flag_2');
    case 3:
      return $r('app.media.cw_flag_3');
    default:
      return $r('app.media.cw_flag_4');
  }
}

/** 亮出来的雷，按真实雷型取图 */
export function mineSprite(t: number, mode: number = MODE_COMPLEX): Resource {
  if (mode === MODE_HYPER && (t === 3 || t === 4)) {
    return t === 3 ? $r('app.media.cw_hmine_3') : $r('app.media.cw_hmine_4');
  }
  switch (t) {
    case 1:
      return $r('app.media.cw_mine_1');
    case 2:
      return $r('app.media.cw_mine_2');
    case 3:
      return $r('app.media.cw_mine_3');
    default:
      return $r('app.media.cw_mine_4');
  }
}

/** 踩中的那一颗，同色雷 + 红底 */
export function boomSprite(t: number, mode: number = MODE_COMPLEX): Resource {
  if (mode === MODE_HYPER && (t === 3 || t === 4)) {
    return t === 3 ? $r('app.media.cw_hboom_3') : $r('app.media.cw_hboom_4');
  }
  switch (t) {
    case 1:
      return $r('app.media.cw_boom_1');
    case 2:
      return $r('app.media.cw_boom_2');
    case 3:
      return $r('app.media.cw_boom_3');
    default:
      return $r('app.media.cw_boom_4');
  }
}

/** 结算：插对的旗（插在雷上），按玩家插的那型出图，旗上画绿勾 */
export function rightFlagSprite(t: number, mode: number = MODE_COMPLEX): Resource {
  if (mode === MODE_HYPER && (t === 3 || t === 4)) {
    return t === 3 ? $r('app.media.cw_hrightflag_3') : $r('app.media.cw_hrightflag_4');
  }
  switch (t) {
    case 1:
      return $r('app.media.cw_rightflag_1');
    case 2:
      return $r('app.media.cw_rightflag_2');
    case 3:
      return $r('app.media.cw_rightflag_3');
    default:
      return $r('app.media.cw_rightflag_4');
  }
}

/** 结算：给一个根本不是雷的格子插了旗，旗上画红叉 */
export function wrongBlankSprite(): Resource {
  return $r('app.media.cw_wrongblank');
}

/** 未翻开的格子（立体按钮） */
export function closedSprite(): Resource {
  return $r('app.media.cw_closed');
}

/** 已翻开的空白格 —— 邻域一颗雷都没有 */
export function blankSprite(): Resource {
  return $r('app.media.cw_blank');
}

/** 人脸按钮的五种状态 */
export function faceSprite(kind: number): Resource {
  switch (kind) {
    case 0:
      return $r('app.media.cw_face_down');
    case 1:
      return $r('app.media.cw_face_scan');
    case 2:
      return $r('app.media.cw_face_dead');
    case 3:
      return $r('app.media.cw_face_win');
    default:
      return $r('app.media.cw_face_normal');
  }
}

/** 数码管的一格：0..9 是数字，10 是负号，11 是 i 单位，12 是空格 */
export function ledSprite(cell: number): Resource {
  switch (cell) {
    case 0:
      return $r('app.media.cw_led_0');
    case 1:
      return $r('app.media.cw_led_1');
    case 2:
      return $r('app.media.cw_led_2');
    case 3:
      return $r('app.media.cw_led_3');
    case 4:
      return $r('app.media.cw_led_4');
    case 5:
      return $r('app.media.cw_led_5');
    case 6:
      return $r('app.media.cw_led_6');
    case 7:
      return $r('app.media.cw_led_7');
    case 8:
      return $r('app.media.cw_led_8');
    case 9:
      return $r('app.media.cw_led_9');
    case 10:
      return $r('app.media.cw_led_minus');
    case 11:
      return $r('app.media.cw_led_i');
    case 13:
      return $r('app.media.cw_led_j');
    default:
      return $r('app.media.cw_led_blank');
  }
}

function hyperNumSprite(clue: number): Resource {
  switch (clue) {
    case -64: return $r('app.media.cw_hnum_64_i');
    case -49: return $r('app.media.cw_hnum_49_i');
    case -48: return $r('app.media.cw_hnum_48_i');
    case -36: return $r('app.media.cw_hnum_36_i');
    case -35: return $r('app.media.cw_hnum_35_i');
    case -32: return $r('app.media.cw_hnum_32_i');
    case -25: return $r('app.media.cw_hnum_25_i');
    case -24: return $r('app.media.cw_hnum_24_i');
    case -21: return $r('app.media.cw_hnum_21_i');
    case -16: return $r('app.media.cw_hnum_16_i');
    case -15: return $r('app.media.cw_hnum_15_i');
    case -12: return $r('app.media.cw_hnum_12_i');
    case -9: return $r('app.media.cw_hnum_9_i');
    case -8: return $r('app.media.cw_hnum_8_i');
    case -7: return $r('app.media.cw_hnum_7_i');
    case -5: return $r('app.media.cw_hnum_5_i');
    case -4: return $r('app.media.cw_hnum_4_i');
    case -3: return $r('app.media.cw_hnum_3_i');
    case -1: return $r('app.media.cw_hnum_1_i');
    case 0: return $r('app.media.cw_num_0');
    case 1: return $r('app.media.cw_num_1');
    case 3: return $r('app.media.cw_hnum_3');
    case 4: return $r('app.media.cw_num_4');
    case 5: return $r('app.media.cw_num_5');
    case 7: return $r('app.media.cw_hnum_7');
    case 8: return $r('app.media.cw_num_8');
    case 9: return $r('app.media.cw_num_9');
    case 12: return $r('app.media.cw_hnum_12');
    case 15: return $r('app.media.cw_hnum_15');
    case 16: return $r('app.media.cw_num_16');
    case 21: return $r('app.media.cw_hnum_21');
    case 24: return $r('app.media.cw_hnum_24');
    case 25: return $r('app.media.cw_num_25');
    case 32: return $r('app.media.cw_num_32');
    case 35: return $r('app.media.cw_hnum_35');
    case 36: return $r('app.media.cw_num_36');
    case 48: return $r('app.media.cw_hnum_48');
    case 49: return $r('app.media.cw_num_49');
    case 64: return $r('app.media.cw_num_64');
    default: return $r('app.media.cw_blank');
  }
}
