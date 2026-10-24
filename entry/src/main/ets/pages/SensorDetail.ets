import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { MultiChart } from '../components/MultiChart';
import { COLORS, findSensorDef, SensorDef } from '../model/Catalog';
import { SensorRouteParam } from '../model/Routes';
import { Recorder, SessionMeta } from '../services/Recorder';
import { magnitude, needsRuntimePermission, SensorHub } from '../services/SensorHub';

@Entry
@Component
struct SensorDetail {
  @State values: number[] = [];
  @State chartSeries: number[][] = [];
  @State primaryValue: number = 0;
  @State available: boolean = false;
  @State recording: boolean = false;
  @State elapsed: number = 0;
  @State samples: number = 0;
  @State permissionDenied: boolean = false;
  @State lastMeta: SessionMeta | undefined = undefined;
  @State chartMode: number = 0;
  @State sensorRate: number = 0;
  private def: SensorDef = findSensorDef('acceleration');
  private hub: SensorHub = SensorHub.get();
  private recorder: Recorder = Recorder.get();
  private pendingValues: number[] = [];
  private pendingSeries: number[][] = [];
  private magnitudeSeries: number[] = [];
  private uiTimer: number = -1;
  private recordTimer: number = -1;
  private lastSampleWall: number = 0;
  private started: boolean = false;

  aboutToAppear(): void {
    try {
      let params = router.getParams() as SensorRouteParam;
      if (params !== undefined && params !== null && params.key !== undefined) {
        this.def = findSensorDef(params.key);
      }
    } catch (err) {
      this.def = findSensorDef('acceleration');
    }
    this.hub.refresh();
    this.available = this.hub.isAvailable(this.def.id);
    this.prepareSensor();
  }

  aboutToDisappear(): void {
    if (this.recording) {
      this.finishRecord();
    }
    this.stopTimers();
    this.hub.stop(this.def.id);
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private toast(message: string): void {
    let options: promptAction.ShowToastOptions = { message: message, duration: 2200 };
    this.getUIContext().getPromptAction().showToast(options);
  }

  private async ensurePermission(): Promise<boolean> {
    if (!needsRuntimePermission(this.def.key)) {
      return true;
    }
    let permission: Permissions = this.def.key === 'pedometer' ?
      'ohos.permission.ACTIVITY_MOTION' : 'ohos.permission.READ_HEALTH_DATA';
    try {
      let manager = abilityAccessCtrl.createAtManager();
      let result = await manager.requestPermissionsFromUser(this.context(), [permission]);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (err) {
      return false;
    }
  }

  private async prepareSensor(): Promise<void> {
    this.permissionDenied = false;
    if (!this.available) {
      return;
    }
    let granted: boolean = await this.ensurePermission();
    if (!granted) {
      this.permissionDenied = true;
      return;
    }
    this.startSensor();
  }

  private chartAxes(): string[] {
    if (this.chartMode === 1) {
      return ['模长'];
    }
    if (this.def.axes.length > 4) {
      return this.def.axes.slice(0, 3);
    }
    return this.def.axes;
  }

  private chartColors(): string[] {
    if (this.chartMode === 1) {
      return [COLORS.cyan];
    }
    let colors: string[] = [COLORS.cyan, COLORS.lime, COLORS.rose, COLORS.violet];
    return colors.slice(0, this.chartAxes().length);
  }

  private startSensor(): void {
    if (this.started) {
      return;
    }
    let seriesCount: number = this.chartAxes().length;
    this.pendingSeries = [];
    for (let i = 0; i < seriesCount; i++) {
      this.pendingSeries.push([]);
    }
    this.magnitudeSeries = [];
    let ok: boolean = this.hub.start(this.def, 20000000, (values: number[], ts: number) => {
      this.pendingValues = values;
      this.lastSampleWall = Date.now();
      let count: number = Math.min(this.pendingSeries.length, values.length);
      for (let i = 0; i < count; i++) {
        this.pendingSeries[i].push(values[i]);
        if (this.pendingSeries[i].length > 160) {
          this.pendingSeries[i].shift();
        }
      }
      let mag: number = magnitude(values, Math.min(3, values.length));
      this.magnitudeSeries.push(mag);
      if (this.magnitudeSeries.length > 160) {
        this.magnitudeSeries.shift();
      }
      if (this.recording) {
        this.recorder.add(this.def.key, values);
      }
    });
    if (!ok) {
      this.toast('传感器订阅失败，可能被系统占用');
      return;
    }
    this.started = true;
    this.sensorRate = 50;
    this.uiTimer = setInterval(() => {
      this.values = this.pendingValues.slice();
      this.primaryValue = this.computePrimary(this.pendingValues);
      if (this.chartMode === 1) {
        this.chartSeries = [this.magnitudeSeries.slice()];
      } else {
        let next: number[][] = [];
        for (let i = 0; i < this.pendingSeries.length; i++) {
          next.push(this.pendingSeries[i].slice());
        }
        this.chartSeries = next;
      }
      if (this.recording) {
        this.elapsed = this.recorder.elapsedMs();
        this.samples = this.recorder.sampleCount();
      }
    }, 80);
  }

  private computePrimary(values: number[]): number {
    if (values.length === 0) {
      return 0;
    }
    if (this.def.key === 'barometer' || this.def.key === 'ambientLight' || this.def.key === 'proximity' ||
      this.def.key === 'ambientTemperature' || this.def.key === 'humidity' || this.def.key === 'pedometer' ||
      this.def.key === 'heartRate' || this.def.key === 'hall' || this.def.key === 'wearDetection') {
      return values[0];
    }
    if (this.def.key === 'orientation') {
      return values[0];
    }
    if (this.def.key === 'rotationVector') {
      return values[3];
    }
    if (values.length >= 6) {
      return magnitude(values, 3);
    }
    if (values.length >= 3) {
      return magnitude(values, 3);
    }
    return values[0];
  }

  private primaryLabel(): string {
    if (this.def.key === 'barometer') {
      return '气压';
    }
    if (this.def.key === 'ambientLight') {
      return '照度';
    }
    if (this.def.key === 'proximity') {
      return '距离';
    }
    if (this.def.key === 'ambientTemperature') {
      return '温度';
    }
    if (this.def.key === 'humidity') {
      return '湿度';
    }
    if (this.def.key === 'pedometer') {
      return '步数';
    }
    if (this.def.key === 'heartRate') {
      return '心率';
    }
    if (this.def.key === 'orientation') {
      return '方位角';
    }
    if (this.def.key === 'rotationVector') {
      return 'w 分量';
    }
    if (this.def.axes.length > 1) {
      return '矢量模长';
    }
    return this.def.axes[0];
  }

  private primaryDigits(): number {
    if (this.def.key === 'pedometer' || this.def.key === 'heartRate') {
      return 0;
    }
    if (this.def.key === 'barometer') {
      return 2;
    }
    if (this.def.key === 'ambientLight' || this.def.key === 'proximity') {
      return 1;
    }
    return 2;
  }

  private stopTimers(): void {
    if (this.uiTimer >= 0) {
      clearInterval(this.uiTimer);
      this.uiTimer = -1;
    }
    if (this.recordTimer >= 0) {
      clearInterval(this.recordTimer);
      this.recordTimer = -1;
    }
  }

  private toggleChartMode(): void {
    this.chartMode = this.chartMode === 0 ? 1 : 0;
    this.chartSeries = this.chartMode === 1 ? [this.magnitudeSeries.slice()] : this.pendingSeries.map(
      (item: number[]) => item.slice()
    );
  }

  private startRecord(): void {
    if (!this.available) {
      this.toast('此传感器在当前设备不可用');
      return;
    }
    if (this.recording) {
      return;
    }
    this.recorder.start(`传感器 · ${this.def.name}`, [this.def], '');
    this.recording = true;
    this.elapsed = 0;
    this.samples = 0;
    this.recordTimer = setInterval(() => {
      this.elapsed = this.recorder.elapsedMs();
      this.samples = this.recorder.sampleCount();
    }, 250);
    this.toast('开始记录');
  }

  private finishRecord(): void {
    if (!this.recording) {
      return;
    }
    if (this.recordTimer >= 0) {
      clearInterval(this.recordTimer);
      this.recordTimer = -1;
    }
    let meta: SessionMeta = this.recorder.stop(this.context());
    this.recording = false;
    this.lastMeta = meta;
    this.toast(`已保存 ${meta.samples} 个样本`);
  }

  private async exportLast(): Promise<void> {
    if (this.recording) {
      this.finishRecord();
    }
    if (this.lastMeta === undefined) {
      this.toast('完成一次记录后即可导出');
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

  private axisValue(index: number): string {
    if (index >= this.values.length) {
      return '暂无';
    }
    if (this.def.key === 'pedometer' || this.def.key === 'heartRate') {
      return this.values[index].toFixed(0);
    }
    return this.values[index].toFixed(3);
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
        Text(this.def.name)
          .fontSize(28)
          .fontColor(COLORS.text)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-0.5)
        Text(this.def.en)
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
          .backgroundColor(this.available ? COLORS.lime : COLORS.textMuted)
        Text(this.available ? '已连接' : '不可用')
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
  hero() {
    Column({ space: 8 }) {
      Row() {
        Text(this.primaryLabel())
          .fontSize(13)
          .fontColor(COLORS.textSecondary)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(this.available ? '实时 · 50 Hz' : '无信号')
          .fontSize(11)
          .fontColor(this.available ? COLORS.blue : COLORS.textMuted)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor(this.available ? '#EEF5FF' : COLORS.surfaceHigh)
          .borderRadius(999)
      }
      .width('100%')
      Row({ space: 8 }) {
        Text(this.primaryValue.toFixed(this.primaryDigits()))
          .fontSize(54)
          .fontColor(COLORS.text)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-2)
        Text(this.def.unit)
          .fontSize(15)
          .fontColor(COLORS.textMuted)
          .padding({ bottom: 10 })
      }
      .alignItems(VerticalAlign.Bottom)
      .width('100%')
      Text(this.available ? '传感器数据直接来自系统 Sensor Service' : '系统未向第三方应用注册该传感器')
        .fontSize(12)
        .fontColor(COLORS.textMuted)
        .width('100%')
    }
    .width('100%')
    .padding(20)
    .backgroundColor(COLORS.surface)
    .borderRadius(26)
    .shadow({ radius: 24, color: '#0D000000', offsetX: 0, offsetY: 8 })
  }

  @Builder
  chartCard() {
    Column({ space: 10 }) {
      Row() {
        Text('实时波形')
          .fontSize(15)
          .fontColor(COLORS.text)
          .fontWeight(FontWeight.Bold)
        Blank()
        if (this.def.axes.length > 1) {
          Text(this.chartMode === 0 ? '分量' : '模长')
            .fontSize(11)
            .fontColor(COLORS.textSecondary)
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(999)
            .backgroundColor(COLORS.surfaceHigh)
            .onClick(() => this.toggleChartMode())
        }
      }
      .width('100%')
      Stack() {
        MultiChart({
          series: this.chartSeries,
          colors: this.chartColors(),
          autoScale: true,
          showZero: this.def.key === 'acceleration' || this.def.key === 'gyroscope' ||
            this.def.key === 'magneticField' || this.def.key === 'linearAcceleration'
        })
      }
      .width('100%')
      .height(200)
      .clip(true)
      Row({ space: 14 }) {
        ForEach(this.chartAxes(), (axis: string, index: number) => {
          Row({ space: 5 }) {
            Row()
              .width(7)
              .height(7)
              .borderRadius(999)
              .backgroundColor(this.chartColors()[index])
            Text(axis)
              .fontSize(11)
              .fontColor(COLORS.textSecondary)
          }
        }, (axis: string) => axis)
        Blank()
        Text('160 点窗口')
          .fontSize(10)
          .fontColor(COLORS.textMuted)
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
  axisGrid() {
    Column({ space: 10 }) {
      Row() {
        Text('当前读数')
          .fontSize(15)
          .fontColor(COLORS.text)
          .fontWeight(FontWeight.Bold)
        Blank()
        Text(this.hub.hardwareSummary(this.def))
          .fontSize(10)
          .fontColor(COLORS.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('58%')
          .textAlign(TextAlign.End)
      }
      .width('100%')
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
        ForEach(this.def.axes, (axis: string, index: number) => {
          Column({ space: 5 }) {
            Text(axis)
              .fontSize(11)
              .fontColor(COLORS.textMuted)
            Text(this.axisValue(index))
              .fontSize(20)
              .fontColor(COLORS.text)
              .fontWeight(FontWeight.Medium)
              .letterSpacing(-0.4)
          }
          .alignItems(HorizontalAlign.Start)
          .width(this.def.axes.length > 3 ? '31%' : '48%')
          .padding(12)
          .margin({ bottom: 8 })
          .backgroundColor(COLORS.surfaceHigh)
          .borderRadius(14)
        }, (axis: string) => axis)
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
  recordCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 4 }) {
          Text(this.recording ? '正在记录' : '数据记录')
            .fontSize(17)
            .fontColor(COLORS.text)
            .fontWeight(FontWeight.Bold)
          Text(this.recording ? `${this.formatClock(this.elapsed)} · ${this.samples} 样本` :
            (this.lastMeta === undefined ? '开始后可导出 CSV' : `上次 ${this.lastMeta.samples} 样本`))
            .fontSize(11)
            .fontColor(COLORS.textMuted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.lastMeta !== undefined && !this.recording) {
          Text('导出')
            .fontSize(12)
            .fontColor(COLORS.textSecondary)
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .borderRadius(999)
            .backgroundColor(COLORS.surfaceHigh)
            .onClick(() => this.exportLast())
        }
      }
      .width('100%')
      Text(this.recording ? '停止并保存' : '开始记录传感器数据')
        .fontSize(14)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .width('100%')
        .height(50)
        .borderRadius(999)
        .backgroundColor(COLORS.text)
        .onClick(() => {
          if (this.recording) {
            this.finishRecord();
          } else {
            this.startRecord();
          }
        })
    }
    .width('100%')
    .padding(18)
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
    .border({ width: 1, color: '#E5E5EA' })
  }

  build() {
    Scroll() {
      Column() {
        this.topBar()

        if (!this.available) {
          Column({ space: 8 }) {
            Text('此传感器未开放')
              .fontSize(17)
              .fontColor('#8A5A00')
              .fontWeight(FontWeight.Bold)
            Text('当前华为手机的系统传感器列表中没有这个传感器。第三方应用无法绕过系统直接访问硬件；这是 HarmonyOS 的隐私与权限设计。你仍然可以查看它的专业用途与能力说明。')
              .fontSize(12)
              .fontColor('#6E5A2E')
              .lineHeight(19)
          }
          .width('100%')
          .padding(18)
          .margin({ top: 18 })
          .backgroundColor('#FFF8E6')
          .borderRadius(20)
        } else if (this.permissionDenied) {
          Column({ space: 10 }) {
            Text('需要用户授权')
              .fontSize(17)
              .fontColor('#8A5A00')
              .fontWeight(FontWeight.Bold)
            Text('读取计步器或心率需要健康/运动权限。授权后才会订阅传感器。')
              .fontSize(12)
              .fontColor('#6E5A2E')
              .lineHeight(19)
            Text('重新授权')
              .fontSize(13)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
              .textAlign(TextAlign.Center)
              .height(40)
              .padding({ left: 18, right: 18 })
              .borderRadius(999)
              .backgroundColor(COLORS.text)
              .onClick(() => this.prepareSensor())
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .margin({ top: 18 })
          .backgroundColor('#FFF8E6')
          .borderRadius(20)
        } else {
          this.hero()
          this.chartCard()
          this.axisGrid()
          this.recordCard()
        }

        this.infoCard('这个传感器能做什么', this.def.uses.map((item: string) => `· ${item}`).join('\n'), this.def.color)
        this.infoCard('专业玩法与边界', this.def.professional, COLORS.blue)
        this.infoCard('权限与精度', `${this.def.permission}\n${this.def.accuracy}`, COLORS.textMuted)

        Column({ space: 6 }) {
          Text('提示')
            .fontSize(12)
            .fontColor(COLORS.text)
            .fontWeight(FontWeight.Medium)
          Text('实时曲线用于观察趋势，不用于计量校准。若读数长期不变，请检查系统是否未注册该传感器，或是否有其他应用占用。')
            .fontSize(11)
            .fontColor(COLORS.textSecondary)
            .lineHeight(18)
        }
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
