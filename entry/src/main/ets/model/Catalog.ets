import { sensor } from '@kit.SensorServiceKit';

/**
 * Static description of one physical sensor exposed by HarmonyOS.
 * Only sensors that can be reached through @ohos.sensor are listed.
 */
export interface SensorDef {
  id: sensor.SensorId;
  key: string;
  name: string;
  en: string;
  unit: string;
  axes: string[];
  category: string;
  color: string;
  brief: string;
  uses: string[];
  professional: string;
  permission: string;
  accuracy: string;
}

export interface ExperimentDef {
  id: string;
  name: string;
  en: string;
  subtitle: string;
  sensorKey: string;
  accent: string;
  glyph: string;
  formula: string;
  principle: string;
  steps: string[];
  safety: string;
}

export interface ColorPalette {
  bg: string;
  bgDeep: string;
  surface: string;
  surfaceHigh: string;
  line: string;
  text: string;
  textSecondary: string;
  textMuted: string;
  cyan: string;
  cyanSoft: string;
  lime: string;
  amber: string;
  rose: string;
  violet: string;
  blue: string;
  teal: string;
  indigo: string;
}

export const COLORS: ColorPalette = {
  bg: '#F5F5F7',
  bgDeep: '#FFFFFF',
  surface: '#FFFFFF',
  surfaceHigh: '#F5F5F7',
  line: '#E5E5EA',
  text: '#1D1D1F',
  textSecondary: '#6E6E73',
  textMuted: '#86868B',
  cyan: '#0071E3',
  cyanSoft: '#4B9BFF',
  lime: '#34C759',
  amber: '#FF9F0A',
  rose: '#FF375F',
  violet: '#AF52DE',
  blue: '#0071E3',
  teal: '#30B0C7',
  indigo: '#5856D6'
};

export const SENSOR_DEFS: SensorDef[] = [
  {
    id: sensor.SensorId.ACCELEROMETER,
    key: 'acceleration',
    name: '加速度计',
    en: 'Accelerometer',
    unit: 'm/s²',
    axes: ['X', 'Y', 'Z'],
    category: '运动',
    color: COLORS.cyan,
    brief: '包含重力在内的三轴加速度，鸿蒙手机上采样率最高、最通用的传感器。',
    uses: ['自由落体与碰撞冲击', '电梯、车辆加减速', '振动与机械故障初筛', '步态与运动强度'],
    professional: '以 100–200 Hz 采样可做短时振动频谱分析；配合高通滤波可分离线性加速度。手机安装姿态会改变坐标轴，实验前需固定手机并记录朝向。',
    permission: 'ohos.permission.ACCELEROMETER（安装时授予）',
    accuracy: '典型 12–16 位，量程常见 ±2 g / ±4 g / ±8 g；消费级 MEMS 噪声高于专业加速度计。'
  },
  {
    id: sensor.SensorId.LINEAR_ACCELEROMETER,
    key: 'linearAcceleration',
    name: '线性加速度计',
    en: 'Linear acceleration',
    unit: 'm/s²',
    axes: ['X', 'Y', 'Z'],
    category: '运动',
    color: COLORS.blue,
    brief: '系统融合去重力后的加速度，适合看“纯粹的运动”而不是重力方向。',
    uses: ['振动监测', '冲击与制动分析', '运动轨迹的短期推算'],
    professional: '相比原始加速度计省去重力分离步骤，但它是厂商融合结果，滤波参数不透明；做严谨的频域分析时优先使用原始加速度计并自行去趋势。',
    permission: 'ohos.permission.ACCELEROMETER（安装时授予）',
    accuracy: '精度取决于厂商融合算法；积分求速度/位移会快速漂移，只适合数秒级短时分析。'
  },
  {
    id: sensor.SensorId.GYROSCOPE,
    key: 'gyroscope',
    name: '陀螺仪',
    en: 'Gyroscope',
    unit: 'rad/s',
    axes: ['X', 'Y', 'Z'],
    category: '运动',
    color: COLORS.violet,
    brief: '测量绕三轴的角速度，是转动、姿态与稳定控制的直接信号。',
    uses: ['角速度与转速测量', '转动惯量/摩擦实验', '姿态解算与云台稳定', '车辆横摆角速度'],
    professional: '对角速度积分可得角度，但零偏会累积漂移；长期姿态应使用旋转矢量或做零偏校准。适合测量电机转速、转盘周期与人体关节角速度。',
    permission: 'ohos.permission.GYROSCOPE（安装时授予）',
    accuracy: '消费级零偏常见 0.01–0.1 °/s，积分 1 分钟可能漂移数度；温度变化会显著影响零偏。'
  },
  {
    id: sensor.SensorId.MAGNETIC_FIELD,
    key: 'magneticField',
    name: '磁力计',
    en: 'Magnetometer',
    unit: 'μT',
    axes: ['X', 'Y', 'Z'],
    category: '电磁',
    color: COLORS.rose,
    brief: '测量当地磁场矢量，可当指南针、金属探测器和电流磁场的粗略探针。',
    uses: ['地磁场与方位角', '铁磁材料探测', '扬声器/电机漏磁检查', '磁罗盘校准'],
    professional: '地磁场约 25–65 μT。检测铁磁物体时看总场强相对基线偏移；检测载流导线需要交流磁场，手机采样率和噪声通常不足以做精确电流测量。远离手机扬声器与磁吸配件。',
    permission: '无需用户授权（系统能力）',
    accuracy: '典型分辨率 0.1–1 μT；硬铁/软铁干扰需做 8 字校准，手机内部扬声器磁体是主要干扰源。'
  },
  {
    id: sensor.SensorId.GRAVITY,
    key: 'gravity',
    name: '重力传感器',
    en: 'Gravity',
    unit: 'm/s²',
    axes: ['X', 'Y', 'Z'],
    category: '姿态',
    color: COLORS.amber,
    brief: '分离出的重力矢量，可直接计算手机相对水平面的倾角。',
    uses: ['电子水平仪', '坡度与倾角测量', '安装姿态校准', '静态重力方向'],
    professional: '静止时总模长约 9.8 m/s²。倾斜角 θ=acos(gz/|g|)，双轴坡度可用 atan2 计算。动态加速度会污染结果，运动场景应改用旋转矢量。',
    permission: '无需用户授权（系统融合）',
    accuracy: '静态倾角精度约 0.5–2°，受加速度计噪声与融合滤波影响。'
  },
  {
    id: sensor.SensorId.ROTATION_VECTOR,
    key: 'rotationVector',
    name: '旋转矢量',
    en: 'Rotation vector',
    unit: '',
    axes: ['x', 'y', 'z', 'w'],
    category: '姿态',
    color: COLORS.cyanSoft,
    brief: '以单位四元数表示设备在空间中的三维姿态，适合做 AR、姿态仪和稳定控制。',
    uses: ['三维姿态可视化', '头部/关节朝向追踪', '相机与云台增稳', '四元数教学'],
    professional: '四元数避免欧拉角万向节死锁。可转换为旋转矩阵或欧拉角；与陀螺仪做互补滤波能兼顾低频绝对姿态和高频动态响应。',
    permission: '无需用户授权（系统融合）',
    accuracy: '航向角受磁干扰，横滚/俯仰较稳；典型静态误差 1–3°。'
  },
  {
    id: sensor.SensorId.ORIENTATION,
    key: 'orientation',
    name: '方向传感器',
    en: 'Orientation',
    unit: '°',
    axes: ['α 方位', 'β 俯仰', 'γ 横滚'],
    category: '姿态',
    color: COLORS.blue,
    brief: '把姿态直接输出为欧拉角，读数直观，适合快速搭建仪表。',
    uses: ['指南针与方位角', '手机俯仰/横滚', '太阳能板朝向', '摄影构图水平'],
    professional: '欧拉角存在万向节死锁，且不同厂商的轴向定义可能不同。做跨设备对比或大角度旋转时，记录原始四元数更可靠。',
    permission: '无需用户授权（系统融合）',
    accuracy: '航向依赖磁力计，室内误差可达 10° 以上；俯仰/横滚通常优于 2°。'
  },
  {
    id: sensor.SensorId.BAROMETER,
    key: 'barometer',
    name: '气压计',
    en: 'Barometer',
    unit: 'hPa',
    axes: ['气压'],
    category: '环境',
    color: COLORS.lime,
    brief: '高分辨率大气压，可感知几厘米到几十厘米的高度变化，是室内定位的常用传感器。',
    uses: ['相对高度与楼层判断', '电梯/楼梯垂直速度', '天气短时趋势', '无人机定高'],
    professional: '国际气压高度公式 h=44330[1−(p/p₀)^(1/5.255)]。海平面气压 p₀ 必须用当地天气或已知海拔标定；温度、风与空调气流会造成漂移。手机气压计分辨率常优于 0.1 hPa（约 1 m 量级）。',
    permission: '无需用户授权（系统能力）',
    accuracy: '绝对高度误差取决于 p₀，相对高度可到 0.1–1 m；快速电梯中仍有几帕噪声。'
  },
  {
    id: sensor.SensorId.AMBIENT_LIGHT,
    key: 'ambientLight',
    name: '环境光传感器',
    en: 'Ambient light',
    unit: 'lx',
    axes: ['照度'],
    category: '环境',
    color: COLORS.amber,
    brief: '测量环境照度，可做光照记录、屏幕亮度实验与植物光照比较。',
    uses: ['教室/办公室照度测量', '灯具频闪的慢速包络', '日出日落光强曲线', '拍照曝光参考'],
    professional: '照度计需按余弦修正和光谱匹配；手机传感器通常未做专业校准，只适合相对比较。采样率低，不能直接测 100 Hz 频闪，但可观察慢速变化。',
    permission: '无需用户授权（系统能力）',
    accuracy: '消费级光传感器相对误差可达 ±20%，不同色温光源下偏差更大。'
  },
  {
    id: sensor.SensorId.PROXIMITY,
    key: 'proximity',
    name: '接近光传感器',
    en: 'Proximity',
    unit: 'cm',
    axes: ['距离'],
    category: '环境',
    color: COLORS.rose,
    brief: '检测遮挡物靠近，通常是红外接近传感器，输出距离或近/远状态。',
    uses: ['手势与遮挡检测', '口袋/保护壳识别', '自动熄屏逻辑验证', '简单占位传感'],
    professional: '多数手机只输出二元“近/远”而非连续距离，量程仅几厘米。可做重复性计数或交互触发，不适合精确测距。',
    permission: '无需用户授权（系统能力）',
    accuracy: '典型阈值 0–5 cm，受物体反射率影响；深色物体检测距离更短。'
  },
  {
    id: sensor.SensorId.AMBIENT_TEMPERATURE,
    key: 'ambientTemperature',
    name: '环境温度',
    en: 'Ambient temperature',
    unit: '°C',
    axes: ['温度'],
    category: '环境',
    color: COLORS.amber,
    brief: '部分机型提供环境温度，但多数华为手机不向三方应用开放独立温度传感器。',
    uses: ['室温趋势（需校准）', '设备热环境记录', '温度补偿参考'],
    professional: '手机内部温度受 SoC、电池和充电发热影响，读数往往不是真实气温。做定量实验需与标准温度计对比并做稳态校准，不能替代气象温度计。',
    permission: '视机型而定；若不可用则列表显示“不支持”',
    accuracy: '误差可能达数摄氏度，且随负载变化；仅适合趋势观察。'
  },
  {
    id: sensor.SensorId.HUMIDITY,
    key: 'humidity',
    name: '湿度传感器',
    en: 'Humidity',
    unit: '%RH',
    axes: ['相对湿度'],
    category: '环境',
    color: COLORS.blue,
    brief: '少数机型提供相对湿度，可用于梅雨、温室与室内舒适度记录。',
    uses: ['室内湿度趋势', '除湿/加湿效果对比', '霉菌风险提示', '温室环境记录'],
    professional: '相对湿度随温度变化，比较不同房间时同时记录温度。传感器若靠近机身发热区，读数会偏低，需静置并避免手握。',
    permission: '视机型而定；若不可用则列表显示“不支持”',
    accuracy: '典型 ±3–5 %RH，长期漂移需校准。'
  },
  {
    id: sensor.SensorId.PEDOMETER,
    key: 'pedometer',
    name: '计步器',
    en: 'Pedometer',
    unit: '步',
    axes: ['累计步数'],
    category: '健康',
    color: COLORS.lime,
    brief: '系统累计步数，可用于步频、步数与日常活动量的粗略统计。',
    uses: ['步数与步频', '步行/跑步节奏', '活动量对比', '步态实验的时间基准'],
    professional: '计步器是系统融合结果，无法获得每一步的精确触地时刻。做步态研究应同时记录加速度原始波形，用峰值检测提取步频与对称性。',
    permission: 'ohos.permission.ACTIVITY_MOTION（用户授权）',
    accuracy: '步数误差通常 1–5%，口袋/手持/摆臂方式影响明显。'
  },
  {
    id: sensor.SensorId.HEART_RATE,
    key: 'heartRate',
    name: '心率传感器',
    en: 'Heart rate',
    unit: 'bpm',
    axes: ['心率'],
    category: '健康',
    color: COLORS.rose,
    brief: '读取 PPG 心率值。多数华为手机不向三方应用直接开放后置 PPG，需系统健康权限或连接穿戴设备。',
    uses: ['静息心率记录', '运动后恢复曲线', '呼吸训练反馈', '生理信号教学'],
    professional: 'PPG 受运动伪影、佩戴松紧与肤色影响。做 HRV 需要逐拍间期（R-R），传感器 API 只给平均 bpm，无法可靠计算 HRV。',
    permission: 'ohos.permission.READ_HEALTH_DATA（用户授权，可能被系统限制）',
    accuracy: '静息 ±3–5 bpm；运动时误差显著增大。'
  },
  {
    id: sensor.SensorId.ACCELEROMETER_UNCALIBRATED,
    key: 'accelUncal',
    name: '未校准加速度计',
    en: 'Raw accelerometer',
    unit: 'm/s²',
    axes: ['X', 'Y', 'Z', 'biasX', 'biasY', 'biasZ'],
    category: '高级',
    color: COLORS.blue,
    brief: '保留原始零偏的加速度数据，适合做传感器标定与误差分析。',
    uses: ['零偏估计', '温度漂移实验', '标定算法教学', '原始数据分析'],
    professional: '通过静态六面法可估计每个轴的零偏与比例因子；未校准数据是研究 MEMS 误差模型的入口，但需要稳定的机械夹具。',
    permission: 'ohos.permission.ACCELEROMETER（安装时授予）',
    accuracy: '原始值含零偏和噪声，未经厂商补偿。'
  },
  {
    id: sensor.SensorId.GYROSCOPE_UNCALIBRATED,
    key: 'gyroUncal',
    name: '未校准陀螺仪',
    en: 'Raw gyroscope',
    unit: 'rad/s',
    axes: ['X', 'Y', 'Z', 'biasX', 'biasY', 'biasZ'],
    category: '高级',
    color: COLORS.violet,
    brief: '保留零偏的原始角速度，适合零偏稳定性与积分漂移实验。',
    uses: ['零偏与噪声分析', 'Allan 方差入门', '积分角度漂移', '温漂实验'],
    professional: '静置采集 10–30 分钟可观察零偏随温度漂移；对未校准数据先减去 bias 再积分，能直观看到消费级 IMU 的误差累积。',
    permission: 'ohos.permission.GYROSCOPE（安装时授予）',
    accuracy: '原始零偏可达 0.1 °/s 量级，需自行补偿。'
  },
  {
    id: sensor.SensorId.HALL,
    key: 'hall',
    name: '霍尔传感器',
    en: 'Hall sensor',
    unit: '',
    axes: ['状态'],
    category: '高级',
    color: COLORS.amber,
    brief: '检测磁铁靠近，通常用于保护壳/翻盖唤醒，部分机型不开放。',
    uses: ['磁吸保护壳识别', '翻盖开合计数', '磁铁位置检测', '开关量实验'],
    professional: '霍尔传感器是开关量而非线性磁场计。可做磁铁极性/距离的阈值实验，但无法给出精确磁感应强度。',
    permission: '无需用户授权（系统能力）',
    accuracy: '阈值触发，受磁铁强度和方向影响。'
  },
  {
    id: sensor.SensorId.WEAR_DETECTION,
    key: 'wearDetection',
    name: '佩戴检测',
    en: 'Wear detection',
    unit: '',
    axes: ['状态'],
    category: '高级',
    color: COLORS.lime,
    brief: '检测设备是否被佩戴，主要出现在手表/手环，手机上通常不可用。',
    uses: ['佩戴状态记录', '省电策略验证', '可穿戴交互'],
    professional: '这是穿戴设备能力，手机侧一般没有。若在手机上显示为不支持属于正常现象。',
    permission: '视设备而定',
    accuracy: '开关量，依赖穿戴检测硬件。'
  }
];

export function findSensorDef(key: string): SensorDef {
  let found: SensorDef | undefined = SENSOR_DEFS.find((item: SensorDef) => item.key === key);
  return found === undefined ? SENSOR_DEFS[0] : found;
}

export const EXPERIMENTS: ExperimentDef[] = [
  {
    id: 'freefall',
    name: '自由落体',
    en: 'FREE FALL',
    subtitle: '用加速度计捕捉失重与撞击，估算下落高度',
    sensorKey: 'acceleration',
    accent: COLORS.blue,
    glyph: '↓',
    formula: 'h ≈ ½ g t²',
    principle: '手机自由下落时，加速度计测得的总加速度接近 0 g；落到软垫产生冲击峰值。用失重持续时间 t 估算下落高度，并反推等效重力加速度。',
    steps: ['把手机平放在柔软厚垫上方 20–40 cm。', '点击“开始实验”，轻推手机使其落下。', '保持 3 秒，应用会自动标记失重区间与冲击。', '读取下落时间、估算高度与冲击峰值。'],
    safety: '务必在厚软垫、床铺或沙发上进行，不要抛接手机，避免摔落损坏。'
  },
  {
    id: 'pendulum',
    name: '单摆与振动',
    en: 'OSCILLATION',
    subtitle: '从周期性加速度中提取周期与频率',
    sensorKey: 'acceleration',
    accent: COLORS.lime,
    glyph: '∿',
    formula: 'T = 1/f,  g ≈ 4π²L/T²',
    principle: '把手机固定在小车、弹簧或单摆上，沿运动方向的加速度呈周期变化。检测波形过零点的时间间隔即可得到周期 T 与频率 f。',
    steps: ['将手机牢固固定在摆杆或弹簧振子上。', '保持传感器轴向与运动方向一致。', '开始实验后轻拉并释放，让系统稳定摆动。', '观察检测到的周期、频率和有效样本数。'],
    safety: '务必固定牢靠，避免手机飞出；摆动幅度建议小于 15°。'
  },
  {
    id: 'rotation',
    name: '转动实验室',
    en: 'ROTATION',
    subtitle: '角速度、转速与累计转角',
    sensorKey: 'gyroscope',
    accent: COLORS.indigo,
    glyph: '⟳',
    formula: 'ω = dθ/dt,  rpm = 60ω/2π',
    principle: '陀螺仪直接输出绕各轴的角速度。对角速度积分得到累计转角；用当前角速度换算每分钟转数，可研究转盘、电机和车轮。',
    steps: ['把手机固定在转盘或车轮上，Z 轴对准转轴。', '开始实验，缓慢加速旋转。', '观察 rpm、峰值角速度与累计角度。', '停止后读取积分漂移，理解零偏的影响。'],
    safety: '固定不牢会导致手机甩出，请使用防滑垫和绑带，并控制转速。'
  },
  {
    id: 'magnetic',
    name: '磁场探针',
    en: 'MAGNETIC FIELD',
    subtitle: '测量总场强，寻找铁磁材料与磁体',
    sensorKey: 'magneticField',
    accent: COLORS.rose,
    glyph: '⌁',
    formula: '|B| = √(Bx²+By²+Bz²)',
    principle: '地磁场在多数地区为 25–65 μT。铁磁物体或磁体会让总场强明显偏离基线；记录相对变化即可做非接触式探测。',
    steps: ['远离磁吸壳、扬声器和金属桌面，先记录基线。', '开始实验，让手机缓慢扫过待测物体。', '观察总场强峰值和相对基线偏移。', '用 8 字轨迹移动手机，可粗略做磁罗盘校准。'],
    safety: '强磁体可能影响手机指南针和磁传感器，避免长时间紧贴；不要靠近心脏起搏器等医疗设备。'
  },
  {
    id: 'barometer',
    name: '气压高度计',
    en: 'BAROMETRIC ALTITUDE',
    subtitle: '用气压变化感知楼层与垂直运动',
    sensorKey: 'barometer',
    accent: COLORS.teal,
    glyph: '⌃',
    formula: 'h = 44330[1−(p/p₀)^0.1903]',
    principle: '大气压随高度近似指数下降。以开始时的气压为基准 p₀，用国际气压高度公式可得到相对高度；对高度求时间导数得到垂直速度。',
    steps: ['在起始楼层静置 5 秒，让气压稳定。', '开始实验，携带手机乘电梯或上下楼。', '观察相对高度、气压变化和垂直速度。', '天气变化会造成缓慢漂移，长时间实验需重新归零。'],
    safety: '上下楼梯时注意脚下，不要盯着屏幕行走。'
  },
  {
    id: 'level',
    name: '电子水平仪',
    en: 'INCLINOMETER',
    subtitle: '用重力矢量测量倾角与双轴水平',
    sensorKey: 'gravity',
    accent: COLORS.amber,
    glyph: '∠',
    formula: 'θ = acos(gz/|g|)',
    principle: '静止时重力矢量指向地心。根据重力在三轴上的投影，可计算手机相对水平面的倾角；X/Y 分量给出气泡偏移方向。',
    steps: ['把手机放在待测平面或支架上。', '开始实验，等待读数稳定。', '观察总倾角、X/Y 坡度和气泡位置。', '旋转手机 90° 可检查双轴安装误差。'],
    safety: '测量高处或机械表面时先确保手机不会滑落。'
  }
];

export function findExperiment(id: string): ExperimentDef {
  let found: ExperimentDef | undefined = EXPERIMENTS.find((item: ExperimentDef) => item.id === id);
  return found === undefined ? EXPERIMENTS[0] : found;
}
