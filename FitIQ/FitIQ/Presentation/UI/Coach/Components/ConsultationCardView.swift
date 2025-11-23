import SwiftUI

struct ConsultationCardView: View {
    
    let summary: ConsultationSummary
    let activateAction: (String) -> Void
    
    private var consultantIcon: String {
        switch summary.consultant {
        case .nutritionist, .fitnessCoach:
            return "sparkles"
        case .wellness:
            return "figure.mind.and.body"
        case .unsure:
            return "questionmark.circle.fill"
        }
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) { // Changed alignment to .center for vertical centering
            
            Image(systemName: consultantIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(summary.consultant.accentColor)
                // Removed .padding(.top, 4) as vertical alignment is now center
            
            VStack(alignment: .leading, spacing: 2) { // Reduced spacing for more compact text
                
                Text(summary.artifactTitle)
                    .font(.subheadline) // Slightly smaller font for consistency with other card titles
                    .fontWeight(.medium) // Medium weight
                    .lineLimit(1) // Limit to one line
                
                Text("\(summary.consultant.rawValue) Consult • \(summary.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption) // Smaller font
                    .foregroundStyle(.secondary) // Secondary color
                    .lineLimit(1)
            }
            
            Spacer()
            
            actionButton
        }
        .padding(.horizontal, 15) // Maintain horizontal padding
        .frame(height: 70) // Fixed height to match ActionCardContent
        .background(Color(.secondarySystemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        // Removed .padding(.horizontal) and .padding(.vertical, 2) here as padding will be applied by parent
    }
    
    @ViewBuilder
    private var actionButton: some View {
        if summary.isActive {
            Text("ACTIVE")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.growthGreen.opacity(0.15))
                .foregroundStyle(Color.growthGreen)
                .clipShape(Capsule())
        } else {
            Button("Activate") {
                activateAction(summary.id)
            }
            .font(.callout.weight(.semibold))
            .buttonStyle(.borderedProminent)
            .tint(.ascendBlue)
        }
    }
}
