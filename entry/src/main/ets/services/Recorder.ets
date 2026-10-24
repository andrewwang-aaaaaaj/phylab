import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { SensorDef } from '../model/Catalog';

export interface RecordRow {
  t: number;
  sensor: string;
  values: number[];
}

export interface SessionMeta {
  id: string;
  name: string;
  startedAt: number;
  durationMs: number;
  samples: number;
  sensors: string[];
  note: string;
}

export interface ExportResult {
  ok: boolean;
  message: string;
}

function pad2(value: number): string {
  return value < 10 ? `0${value}` : `${value}`;
}

function stamp(date: Date): string {
  return `${date.getFullYear()}${pad2(date.getMonth() + 1)}${pad2(date.getDate())}_${pad2(date.getHours())}${pad2(date.getMinutes())}${pad2(date.getSeconds())}`;
}

function safeName(name: string): string {
  return name.replace(/[\\/:*?"<>|\s]+/g, '_');
}

export class Recorder {
  private static instance: Recorder | undefined;
  private recording: boolean = false;
  private startWall: number = 0;
  private startAt: Date = new Date();
  private sessionName: string = '';
  private sensorKeys: string[] = [];
  private rows: RecordRow[] = [];
  private noteText: string = '';
  private limit: number = 400000;

  static get(): Recorder {
    if (Recorder.instance === undefined) {
      Recorder.instance = new Recorder();
    }
    return Recorder.instance;
  }

  isRecording(): boolean {
    return this.recording;
  }

  elapsedMs(): number {
    if (!this.recording) {
      return 0;
    }
    return Date.now() - this.startWall;
  }

  sampleCount(): number {
    return this.rows.length;
  }

  start(name: string, defs: SensorDef[], note: string): void {
    this.recording = true;
    this.startWall = Date.now();
    this.startAt = new Date(this.startWall);
    this.sessionName = name;
    this.sensorKeys = defs.map((item: SensorDef) => item.key);
    this.rows = [];
    this.noteText = note;
  }

  add(key: string, values: number[]): void {
    if (!this.recording) {
      return;
    }
    if (this.rows.length >= this.limit) {
      return;
    }
    this.rows.push({
      t: Date.now() - this.startWall,
      sensor: key,
      values: values.slice(0, 6)
    });
  }

  cancel(): void {
    this.recording = false;
    this.rows = [];
  }

  stop(context: common.Context): SessionMeta {
    let duration: number = this.recording ? Date.now() - this.startWall : 0;
    let meta: SessionMeta = {
      id: `${Date.now()}`,
      name: this.sessionName,
      startedAt: this.startWall,
      durationMs: duration,
      samples: this.rows.length,
      sensors: this.sensorKeys.slice(),
      note: this.noteText
    };
    this.recording = false;
    if (this.rows.length > 0) {
      this.saveToSandbox(context, meta, this.rows);
    }
    return meta;
  }

  getLastCsv(sensors: string[]): string {
    return this.buildCsv(this.rows, sensors);
  }

  private buildCsv(rows: RecordRow[], sensors: string[]): string {
    let lines: string[] = [];
    lines.push('# PhyLab for HarmonyOS - sensor recording');
    lines.push(`# session: ${this.sessionName}`);
    lines.push(`# started_at: ${new Date(this.startWall).toISOString()}`);
    lines.push(`# sensors: ${sensors.join(' + ')}`);
    lines.push('# units differ per sensor. v1..v6 map to the axes documented in the app.');
    lines.push('elapsed_ms,sensor,v1,v2,v3,v4,v5,v6');
    for (let i = 0; i < rows.length; i++) {
      let row: RecordRow = rows[i];
      let fields: string[] = [row.t.toString(), row.sensor];
      for (let k = 0; k < 6; k++) {
        fields.push(k < row.values.length ? row.values[k].toFixed(6) : '');
      }
      lines.push(fields.join(','));
    }
    return lines.join('\n');
  }

  private recordDir(context: common.Context): string {
    let dir: string = `${context.filesDir}/records`;
    if (!fs.accessSync(dir)) {
      fs.mkdirSync(dir);
    }
    return dir;
  }

  private saveToSandbox(context: common.Context, meta: SessionMeta, rows: RecordRow[]): void {
    try {
      let dir: string = this.recordDir(context);
      let csv: string = this.buildCsv(rows, meta.sensors);
      let csvFile = fs.openSync(`${dir}/${meta.id}.csv`, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(csvFile.fd, csv);
      fs.closeSync(csvFile);
      let metaFile = fs.openSync(`${dir}/${meta.id}.json`, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(metaFile.fd, JSON.stringify(meta));
      fs.closeSync(metaFile);
    } catch (err) {
      // A full disk or a revoked sandbox must not crash an ongoing experiment.
    }
  }

  loadHistory(context: common.Context): SessionMeta[] {
    let result: SessionMeta[] = [];
    try {
      let dir: string = this.recordDir(context);
      let names: string[] = fs.listFileSync(dir);
      for (let i = 0; i < names.length; i++) {
        let name: string = names[i];
        if (!name.endsWith('.json')) {
          continue;
        }
        let text: string = fs.readTextSync(`${dir}/${name}`);
        let meta: SessionMeta = JSON.parse(text) as SessionMeta;
        result.push(meta);
      }
    } catch (err) {
      return [];
    }
    result.sort((a: SessionMeta, b: SessionMeta) => b.startedAt - a.startedAt);
    return result;
  }

  async exportSession(context: common.UIAbilityContext, meta: SessionMeta): Promise<ExportResult> {
    try {
      let dir: string = this.recordDir(context);
      let source: string = `${dir}/${meta.id}.csv`;
      let csv: string = '';
      if (fs.accessSync(source)) {
        csv = fs.readTextSync(source);
      } else {
        csv = this.buildCsv(this.rows, meta.sensors);
      }
      let options: picker.DocumentSaveOptions = new picker.DocumentSaveOptions();
      options.newFileNames = [`phylab_${stamp(new Date(meta.startedAt))}_${safeName(meta.name)}.csv`];
      options.fileSuffixChoices = ['.csv'];
      let documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      let uris: string[] = await documentPicker.save(options);
      if (uris.length === 0) {
        return { ok: false, message: '已取消保存' };
      }
      let file = fs.openSync(uris[0], fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, csv);
      fs.closeSync(file);
      return { ok: true, message: 'CSV 已导出到所选位置' };
    } catch (err) {
      return { ok: false, message: '导出失败，请重试或检查存储权限' };
    }
  }

  deleteSession(context: common.Context, meta: SessionMeta): void {
    try {
      let dir: string = this.recordDir(context);
      if (fs.accessSync(`${dir}/${meta.id}.csv`)) {
        fs.unlinkSync(`${dir}/${meta.id}.csv`);
      }
      if (fs.accessSync(`${dir}/${meta.id}.json`)) {
        fs.unlinkSync(`${dir}/${meta.id}.json`);
      }
    } catch (err) {
      // Ignore a file that has already been removed.
    }
  }
}
