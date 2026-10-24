import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { MultiChart } from '../components/MultiChart';
import { COLORS, ExperimentDef, findExperiment, findSensorDef, SensorDef } from '../model/Catalog';
import { ExperimentRouteParam } from '../model/Routes';
import { Recorder, SessionMeta } from '../services/Recorder';
import { magnitude, SensorHub } from '../services/SensorHub';

interface Metric {
  label: string;
  value: string;
  unit: string;
  tone: string;
}

@Entry
@Component
struct ExperimentDetail {
  @State exp: ExperimentDef = findExperiment('freefall');
  @State headlineValue: string = '待测';
  @State headlineLabel: string = '';
  @State headlineUnit: string = '';
  @State metrics: Metric[] = [];
  @State chartSeries: number[][] = [[]];
  @State running: boolean = false;
  @State available: boolean = false;
  @State elapsed: number = 0;
  @State samples: number = 0;
  @State lastMeta: SessionMeta | undefined = undefined;
  private def: SensorDef = findSensorDef('acceleration');
  private hub: SensorHub = SensorHub.get();
  private recorder: Recorder = Recorder.get();
  private chartBuffer: number[] = [];
  private uiTimer: number = -1;
  private sampleTimer: number = -1;
  private lastWall: number = 0;
  private armedAt: number = 0;
  private phase: number = 0;
  private fallStart: number = 0;
  private fallMs: number = 0;
  private fallHeight: number = 0;
  private impactPeak: number = 0;
  private baseline: number = 9.81;
  private baselineSum: number = 0;
  private baselineCount: number = 0;
  private prevSignal: number = 0;
  private lastCrossMs: number = 0;
  private periodMs: number = 0;
  private frequency: number = 0;
  private angleRad: number = 0;
  private rpm: number = 0;
  private peakRpm: number = 0;
  private magBase: number = 0;
  private magBaseSum: number = 0;
  private magBaseCount: number = 0;
  private magPeak: number = 0;
  private pressure0: number = 0;
  private altitude: number = 0;
  private lastAltitude: number = 0;
  private lastAltitudeWall: number = 0;
  private verticalSpeed: number = 0;
  private tilt: number = 0;
  private tiltX: number = 0;
  private tiltY: number = 0;
  private gravityTotal: number = 0;

  aboutToAppear(): void {
    try {
      let params = router.getParams() as ExperimentRouteParam;
      if (params !== undefined && params !== null && params.id !== undefined) {
        this.exp = findExperiment(params.id);
      }
    } catch (err) {
      this.exp = findExperiment('freefall');
    }
    this.def = findSensorDef(this.exp.sensorKey);
    this.hub.refresh();
    this.available = this.hub.isAvailable(this.def.id);
    this.prepareHeadline();
    this.setMetrics();
  }

  aboutToDisappear(): void {
    if (this.running) {
      this.stopExperiment();
    }
    this.hub.stop(this.def.id);
    this.clearTimers();
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private toast(message: string): void {
    let options: promptAction.ShowToastOptions = { message: message, duration: 2200 };
    this.getUIContext().getPromptAction().showToast(options);
  }

  private prepareHeadline(): void {
    this.headlineLabel = '准备就绪';
    this.headlineUnit = '';
    if (this.exp.id === 'freefall') {
      this.headlineLabel = '下落高度';
      this.headlineUnit = 'm';
    } else if (this.exp.id === 'pendulum') {
      this.headlineLabel = '振动周期';
      this.headlineUnit = 's';
    } else if (this.exp.id === 'rotation') {
      this.headlineLabel = '转速';
      this.headlineUnit = 'rpm';
    } else if (this.exp.id === 'magnetic') {
      this.headlineLabel = '总磁感应强度';
      this.headlineUnit = 'μT';
    } else if (this.exp.id === 'barometer') {
      this.headlineLabel = '相对高度';
      this.headlineUnit = 'm';
    } else if (this.exp.id === 'level') {
      this.headlineLabel = '倾角';
      this.headlineUnit = '°';
    }
    this.headlineValue = '待测';
  }

  private resetState(): void {
    this.phase = 0;
    this.armedAt = Date.now() + 600;
    this.fallStart = 0;
    this.fallMs = 0;
    this.fallHeight = 0;
    this.impactPeak = 0;
    this.baseline = 9.81;
    this.baselineSum = 0;
    this.baselineCount = 0;
    this.prevSignal = 0;
    this.lastCrossMs = 0;
    this.periodMs = 0;
    this.frequency = 0;
    this.angleRad = 0;
    this.rpm = 0;
    this.peakRpm = 0;
    this.magBase = 0;
    this.magBaseSum = 0;
    this.magBaseCount = 0;
    this.magPeak = 0;
    this.pressure0 = 0;
    this.altitude = 0;
    this.lastAltitude = 0;
    this.lastAltitudeWall = 0;
    this.verticalSpeed = 0;
    this.tilt = 0;
    this.tiltX = 0;
    this.tiltY = 0;
    this.gravityTotal = 0;
    this.chartBuffer = [];
    this.chartSeries = [[]];
    this.samples = 0;
    this.elapsed = 0;
    this.lastWall = Date.now();
  }

  private startExperiment(): void {
    if (this.running) {
      return;
    }
    if (!this.available) {
      this.toast('此实验所需传感器在当前设备不可用');
      return;
    }
    this.resetState();
    this.recorder.start(this.exp.name, [this.def], `实验 ${this.exp.id}`);
    let interval: number = this.exp.id === 'freefall' ? 5000000 : 10000000;
    let ok: boolean = this.hub.start(this.def, interval, (values: number[], ts: number) => {
      this.onSample(values);
    });
    if (!ok) {
      this.recorder.cancel();
      this.toast('传感器启动失败，请检查权限或稍后重试');
      return;
    }
    this.running = true;
    this.uiTimer = setInterval(() => {
      this.elapsed = this.recorder.elapsedMs();
      this.samples = this.recorder.sampleCount();
      this.setMetrics();
      this.chartSeries = [this.chartBuffer.slice()];
      if (this.elapsed > 180000) {
        this.stopExperiment();
        this.toast('已达到 3 分钟上限，实验自动停止');
      }
    }, 100);
    this.setMetrics();
    this.toast('实验已开始');
  }

  private stopExperiment(): void {
    if (!this.running) {
      return;
    }
    this.hub.stop(this.def.id);
    this.clearTimers();
    let meta: SessionMeta = this.recorder.stop(this.context());
    this.running = false;
    this.lastMeta = meta;
    this.setMetrics();
    this.toast(`实验结束，已保存 ${meta.samples} 个样本`);
  }

  private clearTimers(): void {
    if (this.uiTimer >= 0) {
      clearInterval(this.uiTimer);
      this.uiTimer = -1;
    }
    if (this.sampleTimer >= 0) {
      clearInterval(this.sampleTimer);
      this.sampleTimer = -1;
    }
  }

  private pushChart(value: number): void {
    this.chartBuffer.push(value);
    if (this.chartBuffer.length > 180) {
      this.chartBuffer.shift();
    }
  }

  private onSample(values: number[]): void {
    if (values.length === 0) {
      return;
    }
    this.lastWall = Date.now();
    this.samples++;
    this.recorder.add(this.def.key, values);
    if (this.exp.id === 'freefall') {
      this.handleFreefall(values);
    } else if (this.exp.id === 'pendulum') {
      this.handlePendulum(values);
    } else if (this.exp.id === 'rotation') {
      this.handleRotation(values);
    } else if (this.exp.id === 'magnetic') {
      this.handleMagnetic(values);
    } else if (this.exp.id === 'barometer') {
      this.handleBarometer(values);
    } else if (this.exp.id === 'level') {
      this.handleLevel(values);
    }
  }

  private handleFreefall(values: number[]): void {
    let mag: number = magnitude(values, 3);
    this.pushChart(mag);
    if (this.phase === 0 && Date.now() > this.armedAt && mag < 3.2) {
      this.phase = 1;
      this.fallStart = Date.now();
      this.impactPeak = 0;
    } else if (this.phase === 1) {
      if (mag > this.impactPeak) {
        this.impactPeak = mag;
      }
      if (mag > 18) {
        this.fallMs = Date.now() - this.fallStart;
        this.fallHeight = 0.5 * 9.81 * Math.pow(this.fallMs / 1000, 2);
        this.phase = 2;
      }
    } else if (this.phase === 2 && mag > this.impactPeak) {
      this.impactPeak = mag;
    }
  }

  private handlePendulum(values: number[]): void {
    let mag: number = magnitude(values, 3);
    if (this.baselineCount < 30) {
      this.baselineSum += mag;
      this.baselineCount++;
      this.baseline = this.baselineSum / this.baselineCount;
    }
    let signal: number = mag - this.baseline;
    this.pushChart(signal);
    if (this.prevSignal < 0 && signal >= 0) {
      let now: number = Date.now();
      if (this.lastCrossMs > 0) {
        let dt: number = now - this.lastCrossMs;
        if (dt > 120 && dt < 6000) {
          this.periodMs = this.periodMs === 0 ? dt : this.periodMs * 0.75 + dt * 0.25;
          this.frequency = 1000 / this.periodMs;
        }
      }
      this.lastCrossMs = now;
    }
    this.prevSignal = signal;
  }

  private handleRotation(values: number[]): void {
    let omega: number = values.length > 2 ? values[2] : values[0];
    let now: number = Date.now();
    let dt: number = this.lastWall > 0 ? (now - this.lastWall) / 1000 : 0;
    this.lastWall = now;
    this.angleRad += omega * dt;
    this.rpm = Math.abs(omega) * 60 / (Math.PI * 2);
    if (this.rpm > this.peakRpm) {
      this.peakRpm = this.rpm;
    }
    this.pushChart(this.rpm);
  }

  private handleMagnetic(values: number[]): void {
    let total: number = magnitude(values, 3);
    if (this.magBaseCount < 20) {
      this.magBaseSum += total;
      this.magBaseCount++;
      this.magBase = this.magBaseSum / this.magBaseCount;
    }
    let delta: number = total - this.magBase;
    if (Math.abs(delta) > this.magPeak) {
      this.magPeak = Math.abs(delta);
    }
    this.pushChart(total);
  }

  private handleBarometer(values: number[]): void {
    let p: number = values[0];
    if (p <= 0) {
      return;
    }
    if (this.pressure0 === 0) {
      this.pressure0 = p;
    }
    this.altitude = 44330 * (1 - Math.pow(p / this.pressure0, 0.1903));
    let now: number = Date.now();
    if (this.lastAltitudeWall > 0 && now - this.lastAltitudeWall > 250) {
      this.verticalSpeed = (this.altitude - this.lastAltitude) / ((now - this.lastAltitudeWall) / 1000);
      this.lastAltitude = this.altitude;
      this.lastAltitudeWall = now;
    } else if (this.lastAltitudeWall === 0) {
      this.lastAltitude = this.altitude;
      this.lastAltitudeWall = now;
    }
    this.pushChart(this.altitude);
  }

  private handleLevel(values: number[]): void {
    let gx: number = values[0];
    let gy: number = values[1];
    let gz: number = values[2];
    this.gravityTotal = Math.sqrt(gx * gx + gy * gy + gz * gz);
    if (this.gravityTotal < 0.1) {
      return;
    }
    let ratio: number = gz / this.gravityTotal;
    if (ratio > 1) {
      ratio = 1;
    }
    if (ratio < -1) {
      ratio = -1;
    }
    this.tilt = Math.acos(ratio) * 180 / Math.PI;
    this.tiltX = Math.atan2(gx, gz) * 180 / Math.PI;
    this.tiltY = Math.atan2(gy, gz) * 180 / Math.PI;
    this.pushChart(this.tilt);
  }

  private setMetrics(): void {
    let list: Metric[] = [];
    if (this.exp.id === 'freefall') {
      let phaseText: string = '等待释放';
      if (this.phase === 1) {
        phaseText = '失重中';
      } else if (this.phase === 2) {
        phaseText = '已捕获撞击';
      }
      list.push({ label: '状态', value: phaseText, unit: '', tone: COLORS.cyan });
      list.push({ label: '失重时长', value: this.fallMs > 0 ? (this.fallMs / 1000).toFixed(3) : '待测', unit: 's', tone: COLORS.lime });
      list.push({ label: '冲击峰值', value: this.impactPeak > 0 ? this.impactPeak.toFixed(1) : '待测', unit: 'm/s²', tone: COLORS.rose });
      list.push({ label: '采样点', value: `${this.samples}`, unit: 'pts', tone: COLORS.textSecondary });
      this.headlineValue = this.phase === 2 ? this.fallHeight.toFixed(3) : '待测';
    } else if (this.exp.id === 'pendulum') {
      list.push({ label: '周期 T', value: this.periodMs > 0 ? (this.periodMs / 1000).toFixed(4) : '待测', unit: 's', tone: COLORS.lime });
      list.push({ label: '频率 f', value: this.frequency > 0 ? this.frequency.toFixed(3) : '待测', unit: 'Hz', tone: COLORS.cyan });
      list.push({ label: '基线 |a|', value: this.baseline.toFixed(2), unit: 'm/s²', tone: COLORS.amber });
      list.push({ label: '采样点', value: `${this.samples}`, unit: 'pts', tone: COLORS.textSecondary });
      this.headlineValue = this.periodMs > 0 ? (this.periodMs / 1000).toFixed(3) : '待测';
    } else if (this.exp.id === 'rotation') {
      list.push({ label: '当前转速', value: this.rpm.toFixed(1), unit: 'rpm', tone: COLORS.violet });
      list.push({ label: '峰值转速', value: this.peakRpm.toFixed(1), unit: 'rpm', tone: COLORS.rose });
      list.push({ label: '累计转角', value: (this.angleRad * 180 / Math.PI).toFixed(1), unit: '°', tone: COLORS.lime });
      list.push({ label: '采样点', value: `${this.samples}`, unit: 'pts', tone: COLORS.textSecondary });
      this.headlineValue = this.rpm.toFixed(1);
    } else if (this.exp.id === 'magnetic') {
      let delta: number = this.magBase > 0 ? (this.currentMagneticTotal() - this.magBase) : 0;
      let verdict: string = '地磁场附近';
      if (Math.abs(delta) > 50) {
        verdict = '强磁体';
      } else if (Math.abs(delta) > 5) {
        verdict = '铁磁/金属';
      }
      list.push({ label: '基线', value: this.magBase.toFixed(1), unit: 'μT', tone: COLORS.lime });
      list.push({ label: '相对偏移', value: delta.toFixed(1), unit: 'μT', tone: COLORS.rose });
      list.push({ label: '峰值偏移', value: this.magPeak.toFixed(1), unit: 'μT', tone: COLORS.amber });
      list.push({ label: '判断', value: verdict, unit: '', tone: COLORS.cyan });
      this.headlineValue = this.currentMagneticTotal().toFixed(1);
    } else if (this.exp.id === 'barometer') {
      let trend: string = this.verticalSpeed > 0.3 ? '上升' : (this.verticalSpeed < -0.3 ? '下降' : '平稳');
      list.push({ label: '基准气压', value: this.pressure0.toFixed(2), unit: 'hPa', tone: COLORS.amber });
      list.push({ label: '垂直速度', value: this.verticalSpeed.toFixed(2), unit: 'm/s', tone: COLORS.cyan });
      list.push({ label: '运动趋势', value: trend, unit: '', tone: COLORS.lime });
      list.push({ label: '采样点', value: `${this.samples}`, unit: 'pts', tone: COLORS.textSecondary });
      this.headlineValue = this.altitude.toFixed(2);
    } else if (this.exp.id === 'level') {
      list.push({ label: '总倾角', value: this.tilt.toFixed(2), unit: '°', tone: COLORS.amber });
      list.push({ label: 'X 向坡度', value: this.tiltX.toFixed(2), unit: '°', tone: COLORS.cyan });
      list.push({ label: 'Y 向坡度', value: this.tiltY.toFixed(2), unit: '°', tone: COLORS.lime });
      list.push({ label: '重力模长', value: this.gravityTotal.toFixed(2), unit: 'm/s²', tone: COLORS.textSecondary });
      this.headlineValue = this.tilt.toFixed(2);
    }
    this.metrics = list;
  }

  private currentMagneticTotal(): number {
    if (this.chartBuffer.length === 0) {
      return this.magBase;
    }
    return this.chartBuffer[this.chartBuffer.length - 1];
  }

  private async exportLast(): Promise<void> {
    if (this.running) {
      this.stopExperiment();
    }
    if (this.lastMeta === undefined) {
      this.toast('完成一次实验后即可导出');
      return;
    }
    let result = await this.recorder.exportSession(this.context(), this.lastMeta);
    this.toast(result.message);
  }

  private formatClock(ms: number): string {
    let total: number = Math.floor(ms / 1000);
    let m: number = Math.floor(total / 60);
    let s: number = total % 60;
    let tenth: number = Math.floor((ms % 1000) / 100);
    return `${m < 10 ? '0' : ''}${m}:${s < 10 ? '0' : ''}${s}.${tenth}`;
  }

  @Builder
  topBar() {
    Row({ space: 14 }) {
      Text('‹')
        .fontSize(28)
        .fontColor(COLORS.text)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .backgroundColor(COLORS.surface)
        .borderRadius(999)
        .border({ width: 1, color: COLORS.line })
        .onClick(() => router.back())
      Column({ space: 2 }) {
        Text(this.exp.name)
          .fontSize(28)
          .fontColor(COLORS.text)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-0.5)
        Text(this.exp.en)
          .fontSize(12)
          .fontColor(COLORS.textMuted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Row({ space: 6 }) {
        Row()
          .width(7)
          .height(7)
          .borderRadius(999)
          .backgroundColor(this.running ? COLORS.lime : COLORS.textMuted)
        Text(this.running ? '采集中' : '待机')
          .fontSize(11)
          .fontColor(COLORS.textSecondary)
      }
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .borderRadius(999)
      .backgroundColor(COLORS.surface)
      .border({ width: 1, color: COLORS.line })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  headlineCard() {
    Column({ space: 12 }) {
      Row() {
        Text(this.headlineLabel)
          .fontSize(13)
          .fontColor(COLORS.textSecondary)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(this.exp.formula)
          .fontSize(11)
          .fontColor(COLORS.textMuted)
          .fontFamily('monospace')
      }
      .width('100%')
      Row({ space: 8 }) {
        Text(this.headlineValue)
          .fontSize(this.headlineValue === '待测' ? 26 : 54)
          .fontColor(COLORS.text)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(this.headlineValue === '待测' ? 0 : -2)
        Text(this.headlineUnit)
          .fontSize(15)
          .fontColor(COLORS.textMuted)
          .padding({ bottom: 10 })
      }
      .alignItems(VerticalAlign.Bottom)
      .width('100%')
      Text(this.running ? `运行 ${this.formatClock(this.elapsed)} · ${this.samples} 样本` :
        (this.lastMeta === undefined ? '点击开始，数据会自动保存' : `上次 ${this.lastMeta.samples} 样本`))
        .fontSize(12)
        .fontColor(COLORS.textMuted)
        .width('100%')
      Text(this.running ? '停止并保存' : '开始实验')
        .fontSize(14)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(48)
        .borderRadius(999)
        .backgroundColor(COLORS.text)
        .onClick(() => {
          if (this.running) {
            this.stopExperiment();
          } else {
            this.startExperiment();
          }
        })
    }
    .width('100%')
    .padding(20)
    .margin({ top: 18 })
    .backgroundColor(COLORS.surface)
    .borderRadius(26)
    .shadow({ radius: 24, color: '#0D000000', offsetX: 0, offsetY: 8 })
  }

  @Builder
  chartCard() {
    Column({ space: 10 }) {
      Row() {
        Text(this.chartTitle())
          .fontSize(15)
          .fontColor(COLORS.text)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(this.chartUnit())
          .fontSize(11)
          .fontColor(COLORS.textMuted)
      }
      .width('100%')
      Stack() {
        MultiChart({
          series: this.chartSeries,
          colors: [this.exp.accent],
          autoScale: true,
          showZero: this.exp.id !== 'barometer' && this.exp.id !== 'magnetic' &&
            this.exp.id !== 'level'
        })
      }
      .width('100%')
      .height(200)
      .clip(true)
      Text('曲线只保留最近 180 个点；原始数据以 50–200 Hz 写入 CSV。')
        .fontSize(11)
        .fontColor(COLORS.textMuted)
        .width('100%')
    }
    .width('100%')
    .padding(17)
    .margin({ top: 14 })
    .backgroundColor(COLORS.surface)
    .borderRadius(22)
    .shadow({ radius: 20, color: '#0A000000', offsetX: 0, offsetY: 6 })
  }

  private chartTitle(): string {
    if (this.exp.id === 'freefall') {
      return '加速度模长';
    }
    if (this.exp.id === 'pendulum') {
      return '振动信号 |a| − g';
    }
    if (this.exp.id === 'rotation') {
      return '角速度换算转速';
    }
    if (this.exp.id === 'magnetic') {
      return '总磁感应强度';
    }
    if (this.exp.id === 'barometer') {
      return '相对高度';
    }
    return '倾角';
  }

  private chartUnit(): string {
    if (this.exp.id === 'freefall') {
      return 'm/s²';
    }
    if (this.exp.id === 'pendulum') {
      return 'm/s²';
    }
    if (this.exp.id === 'rotation') {
      return 'rpm';
    }
    if (this.exp.id === 'magnetic') {
      return 'μT';
    }
    return this.exp.id === 'level' ? '°' : 'm';
  }

  @Builder
  metricGrid() {
    Column({ space: 8 }) {
      Row() {
        Text('实验读数')
          .fontSize(15)
          .fontColor(COLORS.text)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(this.available ? '传感器就绪' : '传感器不可用')
          .fontSize(11)
          .fontColor(this.available ? COLORS.lime : COLORS.amber)
      }
      .width('100%')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.metrics, (item: Metric) => {
          Column({ space: 5 }) {
            Text(item.label)
              .fontSize(11)
              .fontColor(COLORS.textMuted)
            Row({ space: 3 }) {
              Text(item.value)
                .fontSize(20)
                .fontColor(item.tone)
                .fontWeight(FontWeight.Medium)
                .letterSpacing(-0.4)
                .maxLines(1)
              Text(item.unit)
                .fontSize(9)
                .fontColor(COLORS.textMuted)
            }
            .alignItems(VerticalAlign.Bottom)
          }
          .alignItems(HorizontalAlign.Start)
          .width('48%')
          .padding(12)
          .margin({ bottom: 8 })
          .backgroundColor(COLORS.surfaceHigh)
          .borderRadius(14)
        }, (item: Metric) => item.label)
      }
      .width('100%')
    }
    .width('100%')
    .padding(17)
    .margin({ top: 14 })
    .backgroundColor(COLORS.surface)
    .borderRadius(22)
    .shadow({ radius: 20, color: '#0A000000', offsetX: 0, offsetY: 6 })
  }

  @Builder
  infoCard(title: string, body: string, accent: string) {
    Column({ space: 8 }) {
      Text(title)
        .fontSize(13)
        .fontColor(accent)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Text(body)
        .fontSize(12)
        .fontColor(COLORS.textSecondary)
        .lineHeight(20)
        .width('100%')
    }
    .width('100%')
    .padding(17)
    .margin({ top: 12 })
    .backgroundColor(COLORS.surface)
    .borderRadius(20)
    .shadow({ radius: 18, color: '#0A000000', offsetX: 0, offsetY: 5 })
  }

  build() {
    Scroll() {
      Column() {
        this.topBar()

        if (!this.available) {
          Column({ space: 8 }) {
            Text('缺少实验所需传感器')
              .fontSize(17)
              .fontColor('#8A5A00')
              .fontWeight(FontWeight.Bold)
            Text(`此实验需要「${this.def.name}」，但当前设备的系统传感器列表未向第三方应用暴露它。可以查看原理与步骤，或换用支持的设备。`)
              .fontSize(12)
              .fontColor('#6E5A2E')
              .lineHeight(19)
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .margin({ top: 18 })
          .backgroundColor('#FFF8E6')
          .borderRadius(20)
        } else {
          this.headlineCard()
          this.chartCard()
          this.metricGrid()
        }

        if (this.lastMeta !== undefined && !this.running) {
          Text('导出本次实验 CSV')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(46)
            .margin({ top: 12 })
            .borderRadius(999)
            .backgroundColor(COLORS.text)
            .onClick(() => this.exportLast())
        }

        this.infoCard('实验原理', this.exp.principle, COLORS.blue)
        this.infoCard('操作步骤', this.exp.steps.map((item: string, index: number) => `${index + 1}. ${item}`).join('\n'), COLORS.blue)
        this.infoCard('安全提示', this.exp.safety, COLORS.rose)

        Column({ space: 5 }) {
          Text(`采样设置：${this.exp.id === 'freefall' ? '200 Hz' : '100 Hz'} · 单传感器 · 自动保存`)
            .fontSize(11)
            .fontColor(COLORS.textMuted)
          Text('实验数据只保存在本机。导出时由系统文件选择器决定目标位置，应用不会联网上传。')
            .fontSize(11)
            .fontColor(COLORS.textMuted)
            .lineHeight(17)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .margin({ top: 12, bottom: 34 })
        .backgroundColor(COLORS.surfaceHigh)
        .borderRadius(18)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 52 })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.bg)
  }
}
