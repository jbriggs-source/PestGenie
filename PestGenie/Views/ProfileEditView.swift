import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var routeViewModel: RouteViewModel
    @EnvironmentObject private var authManager: AuthenticationManager

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var jobTitle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Personal Information")) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 40))

                        VStack(alignment: .leading) {
                            Text("Profile Photo")
                                .font(.headline)
                            Text("Tap to change photo")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Change") {
                            // Handle photo change
                        }
                    }
                    .padding(.vertical, 8)

                    TextField("Full Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                }

                Section(header: Text("Work Information")) {
                    TextField("Job Title", text: $jobTitle)

                    HStack {
                        Text("Years of Experience")
                        Spacer()
                        Text("5 Years")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Employee ID")
                        Spacer()
                        Text("T-12345")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadProfileData()
        }
    }

    private func loadProfileData() {
        name = authManager.currentUser?.name ?? routeViewModel.currentUserName
        email = authManager.currentUser?.email ?? "john.briggs@pestgenie.com"
        phone = "(555) 123-4567"
        jobTitle = "Senior Technician"
    }

    private func saveProfile() {
        // Save profile changes
        print("Saving profile: \(name), \(email), \(phone), \(jobTitle)")
        // TODO: Implement actual save logic
    }
}

struct ProfileEditView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileEditView()
            .environmentObject(RouteViewModel())
            .environmentObject(AuthenticationManager.shared)
    }
}