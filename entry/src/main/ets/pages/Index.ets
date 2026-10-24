import { common } from '@kit.AbilityKit';
import { promptAction, router } from '@kit.ArkUI';
import { MultiChart } from '../components/MultiChart';
import {
  COLORS,
  EXPERIMENTS,
  ExperimentDef,
  findSensorDef,
  SENSOR_DEFS,
  SensorDef
} from '../model/Catalog';
import { ExperimentRouteParam, SensorRouteParam } from '../model/Routes';
import { Recorder, SessionMeta } from '../services/Recorder';
import { magnitude, SensorHub } from '../services/SensorHub';

const CATEGORIES: string[] = ['运动', '姿态', '电磁', '环境', '健康', '高级'];

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State revision: number = 0;
  @State availableCount: number = 0;
  @State previewValue: number = 9.81;
  @State previewAxes: number[] = [0, 0, 0];
  @State previewHistory: number[] = [];
  @State sessions: SessionMeta[] = [];
  @State quickRecording: boolean = false;
  @State quickSamples: number = 0;
  @State quickElapsed: number = 0;
  @State actionBusy: boolean = false;
  private hub: SensorHub = SensorHub.get();
  private recorder: Recorder = Recorder.get();
  private previewPending: number = 9.81;
  private previewRaw: number[] = [0, 0, 0];
  private previewBuffer: number[] = [];
  private previewTimer: number = -1;
  private quickTimer: number = -1;

  aboutToAppear(): void {
    this.refreshSensors();
    this.loadHistory();
    this.startPreview();
  }

  onPageShow(): void {
    this.refreshSensors();
    this.loadHistory();
    if (this.currentTab === 0 && !this.quickRecording) {
      this.startPreview();
    }
  }

  onPageHide(): void {
    // Do not stop the preview here: when a detail page opens, its
    // aboutToAppear runs before this callback and owns the subscription.
  }

  aboutToDisappear(): void {
    this.stopPreview();
    if (this.quickTimer >= 0) {
      clearInterval(this.quickTimer);
      this.quickTimer = -1;
    }
  }

  private refreshSensors(): void {
    this.hub.refresh();
    this.availableCount = this.availableCatalogCount();
    this.revision++;
  }

  private availableCatalogCount(): number {
    let count: number = 0;
    for (let i = 0; i < SENSOR_DEFS.length; i++) {
      if (this.hub.isAvailable(SENSOR_DEFS[i].id)) {
        count++;
      }
    }
    return count;
  }

  private sensorAvailable(def: SensorDef): boolean {
    this.revision;
    return this.hub.isAvailable(def.id);
  }

  private startPreview(): void {
    if (this.quickRecording) {
      return;
    }
    this.stopPreview();
    let def: SensorDef = findSensorDef('acceleration');
    let ok: boolean = this.hub.start(def, 50000000, (values: number[], ts: number) => {
      this.previewPending = magnitude(values, 3);
      this.previewRaw = values.slice(0, 3);
      this.previewBuffer.push(this.previewPending);
      if (this.previewBuffer.length > 140) {
        this.previewBuffer.shift();
      }
    });
    if (!ok) {
      return;
    }
    this.previewTimer = setInterval(() => {
      this.previewValue = this.previewPending;
      this.previewAxes = this.previewRaw.slice();
      this.previewHistory = this.previewBuffer.slice();
    }, 120);
  }

  private stopPreview(): void {
    if (this.previewTimer >= 0) {
      clearInterval(this.previewTimer);
      this.previewTimer = -1;
    }
    this.hub.stop(findSensorDef('acceleration').id);
  }

  private toast(message: string): void {
    let options: promptAction.ShowToastOptions = { message: message, duration: 2200 };
    this.getUIContext().getPromptAction().showToast(options);
  }

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private loadHistory(): void {
    try {
      this.sessions = this.recorder.loadHistory(this.context());
    } catch (err) {
      this.sessions = [];
    }
  }

  private switchTab(index: number): void {
    if (index === this.currentTab) {
      return;
    }
    if (this.currentTab === 0) {
      this.stopPreview();
    }
    this.currentTab = index;
    if (index === 0 && !this.quickRecording) {
      this.startPreview();
    }
    if (index === 2) {
      this.loadHistory();
    }
  }

  private openSensor(def: SensorDef): void {
    if (this.quickRecording) {
      this.toast('请先停止四通道记录，再打开传感器详情');
      return;
    }
    this.stopPreview();
    router.pushUrl({
      url: 'pages/SensorDetail',
      params: new SensorRouteParam(def.key)
    });
  }

  private openExperiment(def: ExperimentDef): void {
    if (this.quickRecording) {
      this.toast('请先停止四通道记录，再开始实验');
      return;
    }
    this.stopPreview();
    router.pushUrl({
      url: 'pages/ExperimentDetail',
      params: new ExperimentRouteParam(def.id)
    });
  }

  private startQuickRecord(): void {
    if (this.quickRecording) {
      return;
    }
    this.stopPreview();
    this.hub.stopAll();
    let defs: SensorDef[] = [
      findSensorDef('acceleration'),
      findSensorDef('gyroscope'),
      findSensorDef('magneticField'),
      findSensorDef('barometer')
    ];
    this.recorder.start('四通道环境记录', defs, '加速度 + 陀螺仪 + 磁场 + 气压');
    for (let i = 0; i < defs.length; i++) {
      let def: SensorDef = defs[i];
      if (!this.hub.isAvailable(def.id)) {
        continue;
      }
      let key: string = def.key;
      this.hub.start(def, 20000000, (values: number[], ts: number) => {
        this.recorder.add(key, values);
      });
    }
    this.quickRecording = true;
    this.quickSamples = 0;
    this.quickElapsed = 0;
    this.quickTimer = setInterval(() => {
      this.quickSamples = this.recorder.sampleCount();
      this.quickElapsed = this.recorder.elapsedMs();
    }, 250);
    this.toast('四通道记录已开始');
  }

  private stopQuickRecord(): void {
    if (!this.quickRecording) {
      return;
    }
    this.hub.stopAll();
    if (this.quickTimer >= 0) {
      clearInterval(this.quickTimer);
      this.quickTimer = -1;
    }
    let meta: SessionMeta = this.recorder.stop(this.context());
    this.quickRecording = false;
    this.quickSamples = 0;
    this.quickElapsed = 0;
    this.loadHistory();
    this.toast(`已保存 ${meta.samples} 个样本`);
  }

  private async exportSession(meta: SessionMeta): Promise<void> {
    if (this.actionBusy) {
      return;
    }
    this.actionBusy = true;
    let result = await this.recorder.exportSession(this.context(), meta);
    this.actionBusy = false;
    this.toast(result.message);
  }

  private deleteSession(meta: SessionMeta): void {
    this.recorder.deleteSession(this.context(), meta);
    this.loadHistory();
    this.toast('记录已删除');
  }

  private formatClock(ms: number): string {
    let total: number = Math.floor(ms / 1000);
    let m: number = Math.floor(total / 60);
    let s: number = total % 60;
    let tenth: number = Math.floor((ms % 1000) / 100);
    return `${m < 10 ? '0' : ''}${m}:${s < 10 ? '0' : ''}${s}.${tenth}`;
  }

  private formatDate(ts: number): string {
    let d: Date = new Date(ts);
    let month: string = d.getMonth() + 1 < 10 ? `0${d.getMonth() + 1}` : `${d.getMonth() + 1}`;
    let day: string = d.getDate() < 10 ? `0${d.getDate()}` : `${d.getDate()}`;
    let hour: string = d.getHours() < 10 ? `0${d.getHours()}` : `${d.getHours()}`;
    let minute: string = d.getMinutes() < 10 ? `0${d.getMinutes()}` : `${d.getMinutes()}`;
    return `${month}-${day} ${hour}:${minute}`;
  }

  @Builder
  header(eyebrow: string, title: string, rightTop: string, rightBottom: string) {
    Column() {
      Row() {
        Column({ space: 1 }) {
          Text(eyebrow)
            .fontSize(12)
            .fontColor(COLORS.textSecondary)
            .fontWeight(FontWeight.Medium)
          Text(title)
            .fontSize(31)
            .fontColor(COLORS.text)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(-0.6)
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Row({ space: 6 }) {
          Row()
            .width(7)
            .height(7)
            .borderRadius(999)
            .backgroundColor(COLORS.lime)
          Text(rightTop)
            .fontSize(11)
            .fontColor(COLORS.textSecondary)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 11, right: 11, top: 7, bottom: 7 })
        .backgroundColor(COLORS.surface)
        .borderRadius(999)
        .border({ width: 1, color: COLORS.line })
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(rightBottom)
        .fontSize(13)
        .fontColor(COLORS.textMuted)
        .width('100%')
        .margin({ top: 7 })
    }
    .width('100%')
  }

  @Builder
  navItem(index: number, normal: Resource, selected: Resource, label: string) {
    Column({ space: 4 }) {
      Image(this.currentTab === index ? selected : normal)
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
      Text(label)
        .fontSize(10)
        .fontColor(this.currentTab === index ? COLORS.blue : COLORS.textMuted)
        .fontWeight(this.currentTab === index ? FontWeight.Medium : FontWeight.Regular)
    }
    .layoutWeight(1)
    .height(62)
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.switchTab(index))
  }

  @Builder
  experimentCard(def: ExperimentDef, index: number) {
    Column({ space: 0 }) {
      Row() {
        Text(index < 9 ? `0${index + 1}` : `${index + 1}`)
          .fontSize(12)
          .fontColor(def.accent)
          .fontWeight(FontWeight.Bold)
          .width(32)
          .height(32)
          .textAlign(TextAlign.Center)
          .backgroundColor(COLORS.surfaceHigh)
          .borderRadius(10)
        Blank()
        Text('›')
          .fontSize(20)
          .fontColor(COLORS.textMuted)
          .fontWeight(FontWeight.Lighter)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(def.name)
        .fontSize(17)
        .fontColor(COLORS.text)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ top: 13 })
      Text(def.subtitle)
        .fontSize(12)
        .fontColor(COLORS.textSecondary)
        .lineHeight(17)
        .maxLines(2)
        .width('100%')
        .margin({ top: 4 })
      Blank()
      Text(def.formula)
        .fontSize(10)
        .fontColor(COLORS.textMuted)
        .fontFamily('monospace')
        .maxLines(1)
        .width('100%')
    }
    .width('48.3%')
    .height(172)
    .padding(15)
    .margin({ bottom: 12 })
    .backgroundColor(COLORS.surface)
    .borderRadius(22)
    .shadow({ radius: 20, color: '#0D000000', offsetX: 0, offsetY: 6 })
    .onClick(() => this.openExperiment(def))
  }

  @Builder
  sensorRow(def: SensorDef) {
    Row({ space: 13 }) {
      Stack() {
        Row()
          .width(38)
          .height(38)
          .borderRadius(11)
          .backgroundColor(COLORS.surfaceHigh)
        Row()
          .width(9)
          .height(9)
          .borderRadius(999)
          .backgroundColor(this.sensorAvailable(def) ? def.color : COLORS.textMuted)
      }
      Column({ space: 3 }) {
        Row({ space: 7 }) {
          Text(def.name)
            .fontSize(16)
            .fontColor(COLORS.text)
            .fontWeight(FontWeight.Medium)
          Text(def.en)
            .fontSize(10)
            .fontColor(COLORS.textMuted)
            .maxLines(1)
        }
        Text(def.brief)
          .fontSize(11)
          .fontColor(COLORS.textSecondary)
          .maxLines(2)
          .lineHeight(16)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Row({ space: 4 }) {
        Text(this.sensorAvailable(def) ? '可用' : '不支持')
          .fontSize(11)
          .fontColor(this.sensorAvailable(def) ? COLORS.lime : COLORS.textMuted)
        Text('›')
          .fontSize(18)
          .fontColor(COLORS.textMuted)
          .fontWeight(FontWeight.Lighter)
      }
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
    .border({ width: { bottom: 1 }, color: COLORS.line })
    .opacity(this.sensorAvailable(def) ? 1 : 0.5)
    .onClick(() => this.openSensor(def))
  }

  @Builder
  sessionRow(meta: SessionMeta) {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text(meta.name)
            .fontSize(16)
            .fontColor(COLORS.text)
            .fontWeight(FontWeight.Medium)
          Text(`${this.formatDate(meta.startedAt)} · ${(meta.durationMs / 1000).toFixed(1)} s · ${meta.samples} 样本`)
            .fontSize(11)
            .fontColor(COLORS.textMuted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('CSV')
          .fontSize(10)
          .fontColor(COLORS.textSecondary)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .borderRadius(999)
          .backgroundColor(COLORS.surfaceHigh)
      }
      .width('100%')
      Text(meta.sensors.join(' · '))
        .fontSize(11)
        .fontColor(COLORS.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row({ space: 12 }) {
        Button(this.actionBusy ? '处理中…' : '导出 CSV', { type: ButtonType.Capsule, stateEffect: true })
          .fontSize(13)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .height(40)
          .backgroundColor(COLORS.text)
          .onClick(() => this.exportSession(meta))
        Button('删除', { type: ButtonType.Normal, stateEffect: true })
          .fontSize(13)
          .fontColor(COLORS.rose)
          .width(72)
          .height(40)
          .backgroundColor(Color.Transparent)
          .onClick(() => this.deleteSession(meta))
      }
      .width('100%')
    }
    .width('100%')
    .padding(18)
    .margin({ bottom: 12 })
    .backgroundColor(COLORS.surface)
    .borderRadius(20)
    .shadow({ radius: 18, color: '#0A000000', offsetX: 0, offsetY: 5 })
  }

  @Builder
  homeContent() {
    Scroll() {
      Column({ space: 0 }) {
        this.header('PhyLab', '物理实验室', '离线', `${this.availableCount} 个传感器 · 实时读取`)

        Stack({ alignContent: Alignment.TopStart }) {
          Column() {
            Row() {
              Row({ space: 6 }) {
                Row()
                  .width(7)
                  .height(7)
                  .borderRadius(999)
                  .backgroundColor(COLORS.blue)
                Text('实时加速度')
                  .fontSize(13)
                  .fontColor(COLORS.textSecondary)
                  .fontWeight(FontWeight.Medium)
              }
              Blank()
              Text('50 Hz')
                .fontSize(11)
                .fontColor(COLORS.textMuted)
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('#F2F2F5')
                .borderRadius(6)
            }
            .width('100%')

            Column({ space: 1 }) {
              Text('合加速度')
                .fontSize(12)
                .fontColor(COLORS.textMuted)
              Row({ space: 7 }) {
                Text(this.previewValue.toFixed(2))
                  .fontSize(60)
                  .fontColor(COLORS.text)
                  .fontWeight(FontWeight.Bold)
                  .letterSpacing(-2.5)
                Text('m/s²')
                  .fontSize(15)
                  .fontColor(COLORS.textMuted)
                  .padding({ bottom: 11 })
              }
              .alignItems(VerticalAlign.Bottom)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .margin({ top: 10 })

            Row({ space: 28 }) {
              ForEach(['X', 'Y', 'Z'], (axis: string, index: number) => {
                Column({ space: 2 }) {
                  Text(axis)
                    .fontSize(10)
                    .fontColor(COLORS.textMuted)
                  Text(this.previewAxes.length > index ? this.previewAxes[index].toFixed(2) : '暂无')
                    .fontSize(15)
                    .fontColor(COLORS.textSecondary)
                    .fontWeight(FontWeight.Medium)
                }
                .alignItems(HorizontalAlign.Start)
              }, (axis: string) => axis)
            }
            .width('100%')
            .margin({ top: 4 })

            Stack() {
              MultiChart({
                series: [this.previewHistory],
                colors: [COLORS.blue],
                autoScale: true,
                showZero: false
              })
            }
            .width('100%')
            .height(90)
            .margin({ top: 8 })
            .clip(true)
          }
          .padding(20)
          .width('100%')
        }
        .width('100%')
        .height(300)
        .margin({ top: 22 })
        .borderRadius(28)
        .linearGradient({
          angle: 155,
          colors: [['#FFFFFF', 0.0], ['#FBFDFF', 0.55], ['#F1F7FF', 1.0]]
        })
        .shadow({ radius: 28, color: '#12000000', offsetX: 0, offsetY: 10 })
        .border({ width: 1, color: '#EDEDF0' })

        Row({ space: 10 }) {
          Row({ space: 6 }) {
            Text('记录数据')
              .fontSize(14)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          .height(50)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(COLORS.text)
          .borderRadius(999)
          .onClick(() => this.switchTab(2))

          Row({ space: 6 }) {
            Text('传感器')
              .fontSize(14)
              .fontColor(COLORS.text)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          .height(50)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(COLORS.surface)
          .borderRadius(999)
          .border({ width: 1, color: COLORS.line })
          .onClick(() => this.switchTab(1))
        }
        .width('100%')
        .margin({ top: 14 })

        Row() {
          Text('实验')
            .fontSize(22)
            .fontColor(COLORS.text)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(-0.3)
          Blank()
          Text(`${EXPERIMENTS.length} 个实验`)
            .fontSize(12)
            .fontColor(COLORS.textMuted)
        }
        .width('100%')
        .margin({ top: 30, bottom: 14 })

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(EXPERIMENTS, (def: ExperimentDef, index: number) => {
            this.experimentCard(def, index)
          }, (def: ExperimentDef) => def.id)
        }
        .width('100%')

        Column({ space: 10 }) {
          Row() {
            Text('为什么是 phyphox 式？')
              .fontSize(15)
              .fontColor(COLORS.text)
              .fontWeight(FontWeight.Bold)
            Blank()
            Text('了解更多 ›')
              .fontSize(12)
              .fontColor(COLORS.blue)
          }
          .width('100%')
          Text('不依赖云端、不采集隐私数据。传感器原始读数直接在手机内完成可视化、实验分析与 CSV 导出，把数据的解释权留给使用者。')
            .fontSize(13)
            .fontColor(COLORS.textSecondary)
            .lineHeight(20)
            .width('100%')
        }
        .width('100%')
        .padding(18)
        .margin({ top: 8, bottom: 24 })
        .backgroundColor(COLORS.surface)
        .borderRadius(20)
        .shadow({ radius: 20, color: '#0A000000', offsetX: 0, offsetY: 6 })
        .onClick(() => this.switchTab(3))
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 52, bottom: 100 })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  sensorsContent() {
    Scroll() {
      Column() {
        this.header('PhyLab', '传感器', '实时', `${this.availableCount} / ${SENSOR_DEFS.length} 可用`)

        Text('HarmonyOS 通过 @ohos.sensor 向第三方应用开放的物理量与融合量。可用性由具体机型决定。')
          .fontSize(13)
          .fontColor(COLORS.textSecondary)
          .lineHeight(20)
          .width('100%')
          .margin({ top: 14 })

        ForEach(CATEGORIES, (category: string) => {
          Column() {
            Row({ space: 8 }) {
              Text(category)
                .fontSize(14)
                .fontColor(COLORS.text)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text(`${SENSOR_DEFS.filter((item: SensorDef) => item.category === category).length}`)
                .fontSize(11)
                .fontColor(COLORS.textMuted)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(COLORS.surfaceHigh)
                .borderRadius(999)
            }
            .width('100%')
            .margin({ top: 16, bottom: 2 })
            .alignItems(VerticalAlign.Center)
            ForEach(SENSOR_DEFS.filter((item: SensorDef) => item.category === category), (def: SensorDef) => {
              this.sensorRow(def)
            }, (def: SensorDef) => def.key)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
          .margin({ top: 16 })
          .backgroundColor(COLORS.surface)
          .borderRadius(22)
          .shadow({ radius: 18, color: '#0A000000', offsetX: 0, offsetY: 5 })
        }, (category: string) => category)

        Column({ space: 7 }) {
          Text('关于“不支持”')
            .fontSize(13)
            .fontColor('#8A5A00')
            .fontWeight(FontWeight.Bold)
          Text('华为手机对不同传感器采用差异化开放策略。环境温度、湿度、心率和霍尔等传感器常见于系统应用或穿戴设备，不一定向第三方应用注册。应用会实时读取系统传感器列表，不伪造数据。')
            .fontSize(12)
            .fontColor('#6E5A2E')
            .lineHeight(19)
        }
        .width('100%')
        .padding(16)
        .margin({ top: 22, bottom: 100 })
        .backgroundColor('#FFF8E6')
        .borderRadius(20)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 52 })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  recordsContent() {
    Scroll() {
      Column() {
        this.header('PhyLab', '记录', 'CSV', `${this.sessions.length} 份记录`)

        Column({ space: 16 }) {
          Row() {
            Column({ space: 4 }) {
              Text(this.quickRecording ? '正在记录' : '四通道记录')
                .fontSize(20)
                .fontColor(COLORS.text)
                .fontWeight(FontWeight.Bold)
              Text('加速度 · 陀螺仪 · 磁场 · 气压')
                .fontSize(13)
                .fontColor(COLORS.textSecondary)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Row({ space: 5 }) {
              Row()
                .width(6)
                .height(6)
                .borderRadius(999)
                .backgroundColor(this.quickRecording ? COLORS.rose : COLORS.textMuted)
              Text(this.quickRecording ? '录制中' : '待机')
                .fontSize(11)
                .fontColor(this.quickRecording ? COLORS.rose : COLORS.textMuted)
            }
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .backgroundColor(COLORS.surfaceHigh)
            .borderRadius(999)
          }
          .width('100%')

          Row({ space: 8 }) {
            Column({ space: 3 }) {
              Text(this.formatClock(this.quickElapsed))
                .fontSize(40)
                .fontColor(this.quickRecording ? COLORS.blue : COLORS.text)
                .fontWeight(FontWeight.Bold)
                .letterSpacing(-1.5)
              Text('时长')
                .fontSize(11)
                .fontColor(COLORS.textMuted)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Column({ space: 3 }) {
              Text(`${this.quickSamples}`)
                .fontSize(40)
                .fontColor(COLORS.text)
                .fontWeight(FontWeight.Bold)
                .letterSpacing(-1.5)
              Text('样本')
                .fontSize(11)
                .fontColor(COLORS.textMuted)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')

          Text(this.quickRecording ? '停止并保存' : '开始记录')
            .fontSize(14)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .width('100%')
            .height(50)
            .borderRadius(999)
            .backgroundColor(COLORS.text)
            .onClick(() => {
              if (this.quickRecording) {
                this.stopQuickRecord();
              } else {
                this.startQuickRecord();
              }
            })
        }
        .width('100%')
        .padding(20)
        .margin({ top: 22 })
        .backgroundColor(COLORS.surface)
        .borderRadius(26)
        .shadow({ radius: 24, color: '#10000000', offsetX: 0, offsetY: 8 })

        Text('记录期间请保持应用在前台。屏幕熄灭或应用进入后台后，系统可能暂停传感器回调。')
          .fontSize(12)
          .fontColor(COLORS.textMuted)
          .lineHeight(18)
          .width('100%')
          .margin({ top: 12 })

        Row() {
          Text('历史记录')
            .fontSize(22)
            .fontColor(COLORS.text)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(-0.3)
          Blank()
          Text('应用沙箱')
            .fontSize(12)
            .fontColor(COLORS.textMuted)
        }
        .width('100%')
        .margin({ top: 30, bottom: 14 })

        if (this.sessions.length === 0) {
          Column({ space: 8 }) {
            Text('还没有记录')
              .fontSize(16)
              .fontColor(COLORS.text)
              .fontWeight(FontWeight.Medium)
            Text('从传感器详情或实验页开始一次采集，\n或直接开启上方的四通道记录。')
              .fontSize(12)
              .fontColor(COLORS.textSecondary)
              .textAlign(TextAlign.Center)
              .lineHeight(18)
          }
          .width('100%')
          .padding({ top: 32, bottom: 32 })
          .backgroundColor(COLORS.surface)
          .borderRadius(22)
          .shadow({ radius: 18, color: '#0A000000', offsetX: 0, offsetY: 5 })
        } else {
          ForEach(this.sessions, (meta: SessionMeta) => {
            this.sessionRow(meta)
          }, (meta: SessionMeta) => meta.id)
        }

        Column({ space: 5 }) {
          Text('CSV 结构')
            .fontSize(12)
            .fontColor(COLORS.text)
            .fontWeight(FontWeight.Medium)
          Text('elapsed_ms, sensor, v1…v6。长表格式便于在 Python / Excel / Origin 中按传感器分组，不会因不同采样率而错位。')
            .fontSize(11)
            .fontColor(COLORS.textSecondary)
            .lineHeight(17)
        }
        .width('100%')
        .padding(16)
        .margin({ top: 18, bottom: 100 })
        .backgroundColor(COLORS.surface)
        .borderRadius(20)
        .shadow({ radius: 18, color: '#0A000000', offsetX: 0, offsetY: 5 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 52 })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  aboutContent() {
    Scroll() {
      Column() {
        this.header('PhyLab', '关于', 'v1.0.0', 'HarmonyOS 7 · API 26')

        Text('把手机\n变成物理实验台。')
          .fontSize(34)
          .fontColor(COLORS.text)
          .fontWeight(FontWeight.Bold)
          .lineHeight(42)
          .letterSpacing(-0.8)
          .width('100%')
          .margin({ top: 24 })

        Text('PhyLab 用 HarmonyOS 原生传感器 API 直接读取硬件，全部计算、绘图和存储都在手机本地完成。不申请网络权限，也不上传任何数据。')
          .fontSize(14)
          .fontColor(COLORS.textSecondary)
          .lineHeight(22)
          .width('100%')
          .margin({ top: 14 })

        Row() {
          Column({ space: 4 }) {
            Text('0')
              .fontSize(32)
              .fontColor(COLORS.text)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(-1)
            Text('网络请求')
              .fontSize(11)
              .fontColor(COLORS.textMuted)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Divider()
            .vertical(true)
            .height(38)
            .strokeWidth(1)
            .color(COLORS.line)
          Column({ space: 4 }) {
            Text(`${this.availableCount}`)
              .fontSize(32)
              .fontColor(COLORS.text)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(-1)
            Text('在线传感器')
              .fontSize(11)
              .fontColor(COLORS.textMuted)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 18 })
          Divider()
            .vertical(true)
            .height(38)
            .strokeWidth(1)
            .color(COLORS.line)
          Column({ space: 4 }) {
            Text(`${EXPERIMENTS.length}`)
              .fontSize(32)
              .fontColor(COLORS.text)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(-1)
            Text('结构化实验')
              .fontSize(11)
              .fontColor(COLORS.textMuted)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding({ left: 18 })
        }
        .width('100%')
        .padding(20)
        .margin({ top: 24 })
        .backgroundColor(COLORS.surface)
        .borderRadius(22)
        .shadow({ radius: 20, color: '#0A000000', offsetX: 0, offsetY: 6 })

        Text('这些传感器能做什么')
          .fontSize(22)
          .fontColor(COLORS.text)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(-0.3)
          .width('100%')
          .margin({ top: 32, bottom: 12 })

        this.proUse('运动与结构', '加速度计 + 陀螺仪', '跌落与碰撞、振动频谱、电梯加减速、电机转速、车辆横摆、步态与平衡。', COLORS.blue)
        this.proUse('姿态与导航', '重力 + 旋转矢量 + 磁力计', '三维姿态、电子水平仪、指南针、云台增稳、室内楼层判断与航向融合。', COLORS.indigo)
        this.proUse('环境与气压', '气压计 + 光 + 温湿度', '相对高度、垂直速度、天气趋势、照度比较、温室与室内舒适度记录。', COLORS.teal)
        this.proUse('健康与交互', '计步 + 心率 + 接近光', '步频与活动量、静息心率趋势、遮挡检测、翻盖与磁吸配件识别。', COLORS.rose)

        Column({ space: 10 }) {
          Text('能力边界')
            .fontSize(14)
            .fontColor('#8A5A00')
            .fontWeight(FontWeight.Bold)
          Text('手机不是计量级仪器，MEMS 传感器有噪声、温漂和量程限制。\n心率、温湿度、霍尔等能力因机型与系统策略而异，应用以实时传感器列表为准。\n本应用不提供医疗诊断，心率数据不能用于临床判断。')
            .fontSize(12)
            .fontColor('#6E5A2E')
            .lineHeight(20)
        }
        .width('100%')
        .padding(18)
        .margin({ top: 22 })
        .backgroundColor('#FFF8E6')
        .borderRadius(20)

        Column({ space: 12 }) {
          Row() {
            Text('构建信息')
              .fontSize(14)
              .fontColor(COLORS.text)
              .fontWeight(FontWeight.Medium)
            Blank()
            Text('HarmonyOS 7 · API 26')
              .fontSize(11)
              .fontColor(COLORS.textMuted)
          }
          .width('100%')
          Row() {
            Text('包名')
              .fontSize(12)
              .fontColor(COLORS.textMuted)
            Blank()
            Text('com.phylab.physlab')
              .fontSize(12)
              .fontColor(COLORS.textSecondary)
              .fontFamily('monospace')
          }
          .width('100%')
          Row() {
            Text('数据位置')
              .fontSize(12)
              .fontColor(COLORS.textMuted)
            Blank()
            Text('应用沙箱 / records')
              .fontSize(12)
              .fontColor(COLORS.textSecondary)
          }
          .width('100%')
        }
        .width('100%')
        .padding(18)
        .margin({ top: 18, bottom: 100 })
        .backgroundColor(COLORS.surface)
        .borderRadius(20)
        .shadow({ radius: 18, color: '#0A000000', offsetX: 0, offsetY: 5 })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 52 })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
  }

  @Builder
  proUse(title: string, sensorName: string, body: string, accent: string) {
    Row({ space: 12 }) {
      Row()
        .width(8)
        .height(8)
        .borderRadius(999)
        .backgroundColor(accent)
        .margin({ top: 7 })
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(title)
            .fontSize(15)
            .fontColor(COLORS.text)
            .fontWeight(FontWeight.Medium)
          Text(sensorName)
            .fontSize(10)
            .fontColor(COLORS.textMuted)
            .maxLines(1)
        }
        .width('100%')
        Text(body)
          .fontSize(12)
          .fontColor(COLORS.textSecondary)
          .lineHeight(19)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: COLORS.line })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.currentTab === 0) {
          this.homeContent()
        } else if (this.currentTab === 1) {
          this.sensorsContent()
        } else if (this.currentTab === 2) {
          this.recordsContent()
        } else {
          this.aboutContent()
        }
      }
      .width('100%')
      .height('100%')

      Row() {
        this.navItem(0, $r('app.media.tab_lab'), $r('app.media.tab_lab_active'), '实验')
        this.navItem(1, $r('app.media.tab_sensors'), $r('app.media.tab_sensors_active'), '传感器')
        this.navItem(2, $r('app.media.tab_records'), $r('app.media.tab_records_active'), '记录')
        this.navItem(3, $r('app.media.tab_about'), $r('app.media.tab_about_active'), '关于')
      }
      .width('100%')
      .height(82)
      .padding({ left: 12, right: 12, bottom: 10 })
      .backgroundColor('#FFFFFF')
      .borderWidth({ top: 1 })
      .borderColor('#E5E5EA')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.bg)
  }
}
