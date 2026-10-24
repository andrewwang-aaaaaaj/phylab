import { COLORS } from '../model/Catalog';

/**
 * Multi-series oscilloscope-like chart drawn with ArkUI Canvas.
 * The parent replaces `series` with a new array whenever new samples arrive,
 * which triggers @Watch and a redraw.
 */
@Component
export struct MultiChart {
  @Prop @Watch('onSeriesChanged') series: number[][] = [];
  @Prop colors: string[] = [COLORS.cyan, COLORS.lime, COLORS.rose];
  @Prop autoScale: boolean = true;
  @Prop minValue: number = -10;
  @Prop maxValue: number = 10;
  @Prop showZero: boolean = true;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;
  private chartWidth: number = 320;
  private chartHeight: number = 160;

  private onSeriesChanged(): void {
    this.draw();
  }

  private draw(): void {
    if (!this.ready || !Number.isFinite(this.chartWidth) || !Number.isFinite(this.chartHeight) ||
      this.chartWidth <= 0 || this.chartHeight <= 0) {
      return;
    }
    let ctx: CanvasRenderingContext2D = this.ctx;
    let w: number = this.chartWidth;
    let h: number = this.chartHeight;
    ctx.clearRect(0, 0, w, h);
    ctx.fillStyle = COLORS.bgDeep;
    ctx.fillRect(0, 0, w, h);

    let low: number = this.minValue;
    let high: number = this.maxValue;
    if (this.autoScale) {
      low = Number.POSITIVE_INFINITY;
      high = Number.NEGATIVE_INFINITY;
      for (let s = 0; s < this.series.length; s++) {
        let values: number[] = this.series[s];
        for (let i = 0; i < values.length; i++) {
          if (values[i] < low) {
            low = values[i];
          }
          if (values[i] > high) {
            high = values[i];
          }
        }
      }
      if (!Number.isFinite(low) || !Number.isFinite(high)) {
        low = -1;
        high = 1;
      }
      let span: number = high - low;
      if (span < 0.000001) {
        low -= 0.5;
        high += 0.5;
      } else {
        low -= span * 0.12;
        high += span * 0.12;
      }
    }
    if (high - low < 0.000001) {
      high = low + 1;
    }

    ctx.strokeStyle = COLORS.line;
    ctx.lineWidth = 1;
    for (let i = 1; i <= 3; i++) {
      let y: number = (h / 4) * i;
      ctx.beginPath();
      ctx.moveTo(0, y);
      ctx.lineTo(w, y);
      ctx.stroke();
    }

    let zeroY: number = h - ((0 - low) / (high - low)) * h;
    if (this.showZero && zeroY >= 0 && zeroY <= h) {
      ctx.strokeStyle = '#D2D2D7';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(0, zeroY);
      ctx.lineTo(w, zeroY);
      ctx.stroke();
    }

    // Apple-style soft area fill for a single series.
    if (this.series.length === 1 && this.series[0].length > 1) {
      let values: number[] = this.series[0];
      let color: string = this.colors.length > 0 ? this.colors[0] : COLORS.cyan;
      ctx.beginPath();
      for (let i = 0; i < values.length; i++) {
        let x: number = (w * i) / (values.length - 1);
        let y: number = h - ((values[i] - low) / (high - low)) * h;
        y = Math.max(0, Math.min(h, y));
        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.lineTo(w, h);
      ctx.lineTo(0, h);
      ctx.closePath();
      ctx.globalAlpha = 0.08;
      ctx.fillStyle = color;
      ctx.fill();
      ctx.globalAlpha = 1;
    }

    for (let s = 0; s < this.series.length; s++) {
      let values: number[] = this.series[s];
      if (values.length < 2) {
        continue;
      }
      let color: string = s < this.colors.length ? this.colors[s] : COLORS.cyan;
      ctx.strokeStyle = color;
      ctx.lineWidth = 2;
      ctx.beginPath();
      for (let i = 0; i < values.length; i++) {
        let x: number = (w * i) / (values.length - 1);
        let y: number = h - ((values[i] - low) / (high - low)) * h;
        if (y < 0) {
          y = 0;
        }
        if (y > h) {
          y = h;
        }
        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.stroke();
      let lastValue: number = values[values.length - 1];
      let lastX: number = w;
      let lastY: number = h - ((lastValue - low) / (high - low)) * h;
      if (lastY >= 0 && lastY <= h) {
        ctx.fillStyle = color;
        ctx.beginPath();
        ctx.arc(lastX - 2, lastY, 3, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.ready = true;
        this.draw();
      })
      .onAreaChange((oldArea: Area, newArea: Area) => {
        let width: number = Number(newArea.width);
        let height: number = Number(newArea.height);
        if (Number.isFinite(width) && Number.isFinite(height) && width > 0 && height > 0) {
          this.chartWidth = width;
          this.chartHeight = height;
          this.draw();
        }
      })
  }
}
