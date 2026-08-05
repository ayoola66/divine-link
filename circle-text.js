/**
 * @schema 2.10
 * @input text: string = "HELLO WORLD • "
 * @input fontSize: number = 16
 * @input color: color = #3B82F6
 * @input strokeThickness: number = 2
 * @input showCircle: boolean = true
 * @input filled: boolean = false
 * @input spacing: number = 1.0
 * @input ringGap: number = 30
 * @input fontFamily: string = "JetBrains Mono"
 * @input circles: number(min=1) = 3
 */

const text = pencil.input.text;
const fontSize = pencil.input.fontSize;
const color = pencil.input.color;
const strokeThickness = pencil.input.strokeThickness;
const showCircle = pencil.input.showCircle;
const filled = pencil.input.filled;
const spacing = pencil.input.spacing;
const ringGap = pencil.input.ringGap;
const fontFamily = pencil.input.fontFamily;
const circleCount = Math.floor(pencil.input.circles);

const cx = pencil.width / 2;
const cy = pencil.height / 2;
const outerRadius = Math.min(pencil.width, pencil.height) / 2 - fontSize * 1.5;

const nodes = [];

for (let c = 0; c < circleCount; c++) {
  const radius = outerRadius - c * ringGap;
  if (radius < fontSize) {
    continue;
  }

  if (showCircle) {
    const circleR = radius + fontSize * 0.75;
    const circle = {
      type: "ellipse",
      x: cx - circleR,
      y: cy - circleR,
      width: circleR * 2,
      height: circleR * 2,
    };
    if (filled) {
      circle.fill = color;
    } else {
      circle.stroke = {
        align: "center",
        thickness: strokeThickness,
        fill: color,
      };
    }
    nodes.push(circle);
  }

  if (text.length === 0) {
    continue;
  }

  const charWidth = fontSize * 0.55 * spacing;
  const angleStep = (charWidth / radius) * (180 / Math.PI);
  const startAngle = -90;
  const totalChars = Math.floor(360 / angleStep);

  let fullText = text;
  while (fullText.length < totalChars) {
    fullText += text;
  }
  fullText = fullText.substring(0, totalChars);

  for (let i = 0; i < fullText.length; i++) {
    const angle = startAngle + i * angleStep;
    const rad = (angle * Math.PI) / 180;

    nodes.push({
      type: "text",
      x: cx + radius * Math.cos(rad),
      y: cy + radius * Math.sin(rad),
      content: fullText[i],
      fontSize: fontSize,
      fontFamily: fontFamily,
      fill: color,
      rotation: -(angle + 90),
    });
  }
}

return nodes;
