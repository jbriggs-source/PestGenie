import SwiftUI

struct UserProfilePictureView: View {
    let profileImageURL: URL?
    let size: CGFloat
    let fallbackColor: Color

    init(
        profileImageURL: URL?,
        size: CGFloat = 32,
        fallbackColor: Color = PestGenieDesignSystem.Colors.secondary
    ) {
        self.profileImageURL = profileImageURL
        self.size = size
        self.fallbackColor = fallbackColor
    }

    var body: some View {
        Group {
            if let profileImageURL = profileImageURL {
                AsyncImage(url: profileImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    profilePlaceholder
                }
            } else {
                profilePlaceholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    Color.white.opacity(0.8),
                    lineWidth: size > 24 ? 2 : 1
                )
        )
        .shadow(
            color: Color.black.opacity(0.1),
            radius: size > 24 ? 2 : 1,
            x: 0,
            y: 1
        )
    }

    private var profilePlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        fallbackColor,
                        fallbackColor.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundColor(.white)
            )
    }
}

struct UserProfilePictureView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // With profile image URL
            UserProfilePictureView(
                profileImageURL: URL(string: "https://example.com/profile.jpg"),
                size: 24
            )

            // Without profile image (fallback)
            UserProfilePictureView(
                profileImageURL: nil,
                size: 24
            )

            // Large size
            UserProfilePictureView(
                profileImageURL: nil,
                size: 64,
                fallbackColor: PestGenieDesignSystem.Colors.primary
            )
        }
        .padding()
    }
}