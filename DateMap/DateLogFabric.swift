import SwiftUI

// MARK: - 패브릭(직물) 질감

/// 카드나 배경 위에 아주 미약하게 깔리는 직물 짜임 질감.
/// 가로·세로 헤어라인을 교차시켜 원단의 결을 흉내낸다.
struct FabricTexture: View {
    var lineColor: Color = .black
    var lineOpacity: Double = 0.045
    var spacing: CGFloat = 3.5

    var body: some View {
        Canvas { context, size in
            var weave = Path()

            var x: CGFloat = 0
            while x < size.width {
                weave.move(to: CGPoint(x: x, y: 0))
                weave.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }

            var y: CGFloat = 0
            while y < size.height {
                weave.move(to: CGPoint(x: 0, y: y))
                weave.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }

            context.stroke(
                weave,
                with: .color(lineColor.opacity(lineOpacity)),
                lineWidth: 0.5
            )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 박음질 스티치 테두리

/// 실로 박음질한 느낌의 점선 테두리.
/// 둥근 캡 스티치 아래에 살짝 어긋난 그림자 실을 겹쳐 입체감을 준다.
struct StitchBorder: View {
    var cornerRadius: CGFloat
    var inset: CGFloat = 7
    var threadColor: Color
    var lineWidth: CGFloat = 1.6

    private var stitchStyle: StrokeStyle {
        StrokeStyle(
            lineWidth: lineWidth,
            lineCap: .round,
            dash: [6, 5]
        )
    }

    var body: some View {
        ZStack {
            // 실이 눌린 자국처럼 보이는 아래층
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: inset)
                .stroke(threadColor.opacity(0.35), style: stitchStyle)
                .offset(x: 0.6, y: 0.9)
                .blur(radius: 0.4)

            // 실제 실
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: inset)
                .stroke(threadColor, style: stitchStyle)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 가로 점선

/// 헤더와 본문 사이 등에 쓰는 가로 점선 구분선.
struct HorizontalDashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

// MARK: - 뒤로가기 버튼

/// 시스템 뒤로가기(원형 글래스 배경) 대신 순수한 < 셰브런만 남긴다.
/// 헤더가 밝으면 어두운 색, 어두우면 흰색으로 표시된다.
private struct DateLogBackChevron: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    let theme: DateLogTheme

    private var chevronColor: Color {
        theme.navigationColorScheme == .light
            ? theme.navigationTextColor
            : .white
    }

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(chevronColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("뒤로")
                }
                .sharedBackgroundVisibility(.hidden)
            }
    }
}

extension View {
    /// 원형 배경 없는 순수 < 뒤로가기 버튼으로 교체한다.
    func dateLogBackChevron(_ theme: DateLogTheme) -> some View {
        modifier(DateLogBackChevron(theme: theme))
    }
}

// MARK: - 공통 카드 스타일

extension View {
    /// 파스텔 배경 위에 올라가는 DateLog 공통 카드 표면.
    func dateLogCard(
        _ theme: DateLogTheme,
        cornerRadius: CGFloat = 18
    ) -> some View {
        self
            .background(theme.cardBackgroundColor)
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(theme.primaryColor.opacity(0.08), lineWidth: 1)
            }
            .shadow(
                color: theme.primaryColor.opacity(0.07),
                radius: 10,
                x: 0,
                y: 5
            )
    }

    /// List / Form의 기본 배경을 걷어내고 테마 파스텔 배경을 깐다.
    func dateLogListBackground(_ theme: DateLogTheme) -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(theme.backgroundColor)
    }
}
