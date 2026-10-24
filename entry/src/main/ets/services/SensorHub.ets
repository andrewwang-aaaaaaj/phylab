import { sensor } from '@kit.SensorServiceKit';
import { SensorDef } from '../model/Catalog';

export type SensorListener = (values: number[], timestamp: number) => void;

/**
 * Thin, defensive wrapper around @ohos.sensor.
 * Keeps subscriptions single-owner so pages can freely switch sensors.
 */
export class SensorHub {
  private static instance: SensorHub | undefined;
  private sensorList: sensor.Sensor[] = [];
  private activeIds: Set<number> = new Set<number>();
  private listeners: Map<number, SensorListener> = new Map<number, SensorListener>();

  static get(): SensorHub {
    if (SensorHub.instance === undefined) {
      SensorHub.instance = new SensorHub();
    }
    return SensorHub.instance;
  }

  refresh(): void {
    try {
      this.sensorList = sensor.getSensorListSync();
    } catch (err) {
      this.sensorList = [];
    }
  }

  getList(): sensor.Sensor[] {
    return this.sensorList;
  }

  isAvailable(id: sensor.SensorId): boolean {
    return this.sensorList.some((item: sensor.Sensor) => item.sensorId === id);
  }

  findInfo(id: sensor.SensorId): sensor.Sensor | undefined {
    return this.sensorList.find((item: sensor.Sensor) => item.sensorId === id);
  }

  hardwareSummary(def: SensorDef): string {
    let info: sensor.Sensor | undefined = this.findInfo(def.id);
    if (info === undefined) {
      return '系统未向三方应用暴露此传感器';
    }
    let maxHz: string = info.minSamplePeriod > 0 ? (1000000000 / info.minSamplePeriod).toFixed(0) : '—';
    return `${info.vendorName || '未知厂商'} · 最高约 ${maxHz} Hz · 量程 ${info.maxRange}`;
  }

  start(def: SensorDef, intervalNs: number, listener: SensorListener): boolean {
    this.stop(def.id);
    let info: sensor.Sensor | undefined = this.findInfo(def.id);
    let interval: number = intervalNs;
    if (info !== undefined) {
      if (info.minSamplePeriod > 0) {
        interval = Math.max(info.minSamplePeriod, interval);
      }
      if (info.maxSamplePeriod > 0) {
        interval = Math.min(info.maxSamplePeriod, interval);
      }
    }
    let options: sensor.Options = { interval: interval };
    let emitted: SensorListener = (values: number[], ts: number) => {
      listener(values, ts);
    };
    try {
      switch (def.id) {
        case sensor.SensorId.ACCELEROMETER:
          sensor.on(sensor.SensorId.ACCELEROMETER,
            (data: sensor.AccelerometerResponse) => emitted([data.x, data.y, data.z], data.timestamp), options);
          break;
        case sensor.SensorId.LINEAR_ACCELEROMETER:
          sensor.on(sensor.SensorId.LINEAR_ACCELEROMETER,
            (data: sensor.LinearAccelerometerResponse) => emitted([data.x, data.y, data.z], data.timestamp), options);
          break;
        case sensor.SensorId.GYROSCOPE:
          sensor.on(sensor.SensorId.GYROSCOPE,
            (data: sensor.GyroscopeResponse) => emitted([data.x, data.y, data.z], data.timestamp), options);
          break;
        case sensor.SensorId.MAGNETIC_FIELD:
          sensor.on(sensor.SensorId.MAGNETIC_FIELD,
            (data: sensor.MagneticFieldResponse) => emitted([data.x, data.y, data.z], data.timestamp), options);
          break;
        case sensor.SensorId.GRAVITY:
          sensor.on(sensor.SensorId.GRAVITY,
            (data: sensor.GravityResponse) => emitted([data.x, data.y, data.z], data.timestamp), options);
          break;
        case sensor.SensorId.ROTATION_VECTOR:
          sensor.on(sensor.SensorId.ROTATION_VECTOR,
            (data: sensor.RotationVectorResponse) => emitted([data.x, data.y, data.z, data.w], data.timestamp), options);
          break;
        case sensor.SensorId.ORIENTATION:
          sensor.on(sensor.SensorId.ORIENTATION,
            (data: sensor.OrientationResponse) => emitted([data.alpha, data.beta, data.gamma], data.timestamp), options);
          break;
        case sensor.SensorId.BAROMETER:
          sensor.on(sensor.SensorId.BAROMETER,
            (data: sensor.BarometerResponse) => emitted([data.pressure], data.timestamp), options);
          break;
        case sensor.SensorId.AMBIENT_LIGHT:
          sensor.on(sensor.SensorId.AMBIENT_LIGHT,
            (data: sensor.LightResponse) => emitted([data.intensity], data.timestamp), options);
          break;
        case sensor.SensorId.PROXIMITY:
          sensor.on(sensor.SensorId.PROXIMITY,
            (data: sensor.ProximityResponse) => emitted([data.distance], data.timestamp), options);
          break;
        case sensor.SensorId.AMBIENT_TEMPERATURE:
          sensor.on(sensor.SensorId.AMBIENT_TEMPERATURE,
            (data: sensor.AmbientTemperatureResponse) => emitted([data.temperature], data.timestamp), options);
          break;
        case sensor.SensorId.HUMIDITY:
          sensor.on(sensor.SensorId.HUMIDITY,
            (data: sensor.HumidityResponse) => emitted([data.humidity], data.timestamp), options);
          break;
        case sensor.SensorId.PEDOMETER:
          sensor.on(sensor.SensorId.PEDOMETER,
            (data: sensor.PedometerResponse) => emitted([data.steps], data.timestamp), options);
          break;
        case sensor.SensorId.HEART_RATE:
          sensor.on(sensor.SensorId.HEART_RATE,
            (data: sensor.HeartRateResponse) => emitted([data.heartRate], data.timestamp), options);
          break;
        case sensor.SensorId.ACCELEROMETER_UNCALIBRATED:
          sensor.on(sensor.SensorId.ACCELEROMETER_UNCALIBRATED,
            (data: sensor.AccelerometerUncalibratedResponse) =>
              emitted([data.x, data.y, data.z, data.biasX, data.biasY, data.biasZ], data.timestamp), options);
          break;
        case sensor.SensorId.GYROSCOPE_UNCALIBRATED:
          sensor.on(sensor.SensorId.GYROSCOPE_UNCALIBRATED,
            (data: sensor.GyroscopeUncalibratedResponse) =>
              emitted([data.x, data.y, data.z, data.biasX, data.biasY, data.biasZ], data.timestamp), options);
          break;
        case sensor.SensorId.HALL:
          sensor.on(sensor.SensorId.HALL,
            (data: sensor.HallResponse) => emitted([data.status], data.timestamp), options);
          break;
        default:
          return false;
      }
      this.activeIds.add(def.id);
      this.listeners.set(def.id, listener);
      return true;
    } catch (err) {
      return false;
    }
  }

  stop(id: sensor.SensorId): void {
    if (!this.activeIds.has(id)) {
      return;
    }
    try {
      switch (id) {
        case sensor.SensorId.ACCELEROMETER:
          sensor.off(sensor.SensorId.ACCELEROMETER);
          break;
        case sensor.SensorId.LINEAR_ACCELEROMETER:
          sensor.off(sensor.SensorId.LINEAR_ACCELEROMETER);
          break;
        case sensor.SensorId.GYROSCOPE:
          sensor.off(sensor.SensorId.GYROSCOPE);
          break;
        case sensor.SensorId.MAGNETIC_FIELD:
          sensor.off(sensor.SensorId.MAGNETIC_FIELD);
          break;
        case sensor.SensorId.GRAVITY:
          sensor.off(sensor.SensorId.GRAVITY);
          break;
        case sensor.SensorId.ROTATION_VECTOR:
          sensor.off(sensor.SensorId.ROTATION_VECTOR);
          break;
        case sensor.SensorId.ORIENTATION:
          sensor.off(sensor.SensorId.ORIENTATION);
          break;
        case sensor.SensorId.BAROMETER:
          sensor.off(sensor.SensorId.BAROMETER);
          break;
        case sensor.SensorId.AMBIENT_LIGHT:
          sensor.off(sensor.SensorId.AMBIENT_LIGHT);
          break;
        case sensor.SensorId.PROXIMITY:
          sensor.off(sensor.SensorId.PROXIMITY);
          break;
        case sensor.SensorId.AMBIENT_TEMPERATURE:
          sensor.off(sensor.SensorId.AMBIENT_TEMPERATURE);
          break;
        case sensor.SensorId.HUMIDITY:
          sensor.off(sensor.SensorId.HUMIDITY);
          break;
        case sensor.SensorId.PEDOMETER:
          sensor.off(sensor.SensorId.PEDOMETER);
          break;
        case sensor.SensorId.HEART_RATE:
          sensor.off(sensor.SensorId.HEART_RATE);
          break;
        case sensor.SensorId.ACCELEROMETER_UNCALIBRATED:
          sensor.off(sensor.SensorId.ACCELEROMETER_UNCALIBRATED);
          break;
        case sensor.SensorId.GYROSCOPE_UNCALIBRATED:
          sensor.off(sensor.SensorId.GYROSCOPE_UNCALIBRATED);
          break;
        case sensor.SensorId.HALL:
          sensor.off(sensor.SensorId.HALL);
          break;
        default:
          break;
      }
    } catch (err) {
      // The sensor may already have been released by the system.
    }
    this.activeIds.delete(id);
    this.listeners.delete(id);
  }

  stopAll(): void {
    let ids: number[] = [];
    this.activeIds.forEach((id: number) => {
      ids.push(id);
    });
    for (let i = 0; i < ids.length; i++) {
      this.stop(ids[i] as sensor.SensorId);
    }
  }
}

export function magnitude(values: number[], count: number): number {
  let sum: number = 0;
  for (let i = 0; i < count && i < values.length; i++) {
    sum += values[i] * values[i];
  }
  return Math.sqrt(sum);
}

export function needsRuntimePermission(key: string): boolean {
  return key === 'pedometer' || key === 'heartRate';
}
