import SwiftUI

struct ProfileImageView: View {
    let authManager: AuthenticationManager?

    var body: some View {
        if let authManager = authManager {
            UserProfilePictureView(
                profileImageURL: authManager.currentUser?.profileImageURL,
                size: PestGenieDesignSystem.Components.Navigation.BottomTab.iconSize,
                fallbackColor: PestGenieDesignSystem.Colors.secondary
            )
        } else {
            UserProfilePictureView(
                profileImageURL: nil,
                size: PestGenieDesignSystem.Components.Navigation.BottomTab.iconSize,
                fallbackColor: PestGenieDesignSystem.Colors.secondary
            )
        }
    }
}

struct ProfileImageView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileImageView(authManager: nil)
    }
}