import CleanerFeatures
import SwiftUI

/// Ringraziamento e link facoltativo Buy Me a Coffee, comune alle tre schermate di conclusione.
struct SupportBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Grazie per aver usato mjm.cleaner!")
                .fontWeight(.semibold)
            Text("Se ti è stato utile, offrimi un caffè.")
                .foregroundStyle(.secondary)
            Link("Offrimi un caffè", destination: SupportLinks.buyMeACoffee)
                .accessibilityLabel(Text("Offrimi un caffè su Buy Me a Coffee"))
                .accessibilityHint(Text("Apre il sito buymeacoffee.com/bugbrew nel browser"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 12)
    }
}
