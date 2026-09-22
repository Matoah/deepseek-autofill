import AppKit

// 生成 AI Autofill 的 App 图标（macOS 圆角矩形模板），
// 输出全套尺寸 PNG + Contents.json 到 Assets.xcassets/AppIcon.appiconset/
// 用法：cd macos-app && swift make-icon.swift
// 想改样式只需调整下面"设计参数"，重新运行即可。

// ---- 设计参数 ----
let topColor = NSColor(srgbRed: 0.24, green: 0.43, blue: 1.00, alpha: 1)    // #3D6EFF 左下
let bottomColor = NSColor(srgbRed: 0.54, green: 0.31, blue: 0.97, alpha: 1) // #8A4FF7 右上
let planeAngle: CGFloat = 38   // 纸飞机抬头角度（度，逆时针）
let planeScale: CGFloat = 0.50 // 纸飞机相对圆角矩形边长（旋转后对角展宽，实际占约 0.57）

// 文件名与像素尺寸（macOS 经典全套；@2x 与相邻 1x 像素重复属正常）
let entries: [(String, Int)] = [
    ("icon16.png", 16), ("icon16@2x.png", 32),
    ("icon32.png", 32), ("icon32@2x.png", 64),
    ("icon128.png", 128), ("icon128@2x.png", 256),
    ("icon256.png", 256), ("icon256@2x.png", 512),
    ("icon512.png", 512), ("icon512@2x.png", 1024),
]

/// Material "send" 图标轮廓（24x24，y 轴向上，尖头朝右）
func makePlanePath() -> CGPath {
    let points: [(Double, Double)] = [(2.01, 3), (23, 12), (2.01, 21), (2.01, 14), (17, 12), (2.01, 10)]
    let path = CGMutablePath()
    path.move(to: CGPoint(x: points[0].0, y: points[0].1))
    for p in points.dropFirst() {
        path.addLine(to: CGPoint(x: p.0, y: p.1))
    }
    path.closeSubpath()
    return path
}

let planePath = makePlanePath()

func drawPlane(in ctx: CGContext, size: CGFloat, side: CGFloat, color: CGColor, offsetX: CGFloat, offsetY: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: size / 2 + offsetX, y: size / 2 + offsetY)
    ctx.rotate(by: planeAngle * .pi / 180)
    let scale = planeScale * side / 24
    ctx.scaleBy(x: scale, y: scale)
    // 24 单位坐标系内图形中心约在 (12.5, 12)
    ctx.translateBy(x: -12.5, y: -12)
    ctx.addPath(planePath)
    ctx.setFillColor(color)
    ctx.fillPath()
    ctx.restoreGState()
}

func renderPNG(px: Int) -> Data {
    let size = CGFloat(px)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { fatalError("无法创建位图") }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    guard let nsContext = NSGraphicsContext(bitmapImageRep: rep) else { fatalError("无法创建图形上下文") }
    NSGraphicsContext.current = nsContext
    let ctx = nsContext.cgContext

    // macOS 模板：画布内 82.4% 边长的圆角矩形，圆角半径约边长 22.37%
    let side = size * 0.824
    let margin = (size - side) / 2
    let radius = side * 0.2237
    let iconRect = CGRect(x: margin, y: margin, width: side, height: side)
    let iconPath = CGPath(roundedRect: iconRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.addPath(iconPath)
    ctx.clip()

    // 对角渐变底色
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [topColor.cgColor, bottomColor.cgColor] as CFArray,
        locations: [0, 1]
    )!
    // 沿飞行方向的渐变（左下 -> 右上）
    ctx.drawLinearGradient(
        gradient,
        start: CGPoint(x: margin, y: margin),
        end: CGPoint(x: margin + side, y: margin + side),
        options: []
    )

    // 左上柔和高光
    let highlight = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [NSColor.white.withAlphaComponent(0.10).cgColor, NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(
        highlight,
        startCenter: CGPoint(x: margin + side * 0.32, y: margin + side * 0.74),
        startRadius: 0,
        endCenter: CGPoint(x: margin + side * 0.32, y: margin + side * 0.74),
        endRadius: side * 0.8,
        options: []
    )
    ctx.restoreGState()

    // 极淡的偏移投影增加层次（小尺寸下省略，避免糊）
    if px >= 64 {
        drawPlane(in: ctx, size: size, side: side,
                  color: NSColor.black.withAlphaComponent(0.20).cgColor,
                  offsetX: -side * 0.012, offsetY: -side * 0.020)
    }
    // 白色纸飞机：整体略往右上偏移，兼顾飞行前方留白与小尺寸下的光学居中
    drawPlane(in: ctx, size: size, side: side, color: NSColor.white.cgColor,
              offsetX: side * 0.02, offsetY: side * 0.015)

    NSGraphicsContext.restoreGraphicsState()
    guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("PNG 编码失败") }
    return data
}

// ---- 输出 ----
let fileManager = FileManager.default
let assetRoot = URL(fileURLWithPath: "Assets.xcassets")
let outputDir = assetRoot.appendingPathComponent("AppIcon.appiconset")
try fileManager.createDirectory(at: outputDir, withIntermediateDirectories: true)

for (name, px) in entries {
    let url = outputDir.appendingPathComponent(name)
    try renderPNG(px: px).write(to: url)
}

let rootContents = """
{"info":{"author":"xcode","version":1}}
"""
try rootContents.write(to: assetRoot.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

let setContents = """
{
  "images" : [
    { "filename" : "icon16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try setContents.write(to: outputDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

print("✅ 图标已生成到 Assets.xcassets/AppIcon.appiconset/（\(entries.count) 个尺寸）")
