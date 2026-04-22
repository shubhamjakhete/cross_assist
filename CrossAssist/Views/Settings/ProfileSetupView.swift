//
//  ProfileSetupView.swift
//  CrossAssist
//

import SwiftUI

struct ProfileSetupView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("userName")         private var userName         = ""
    @AppStorage("userDOB")          private var userDOB          = ""
    @AppStorage("emergencyContact") private var emergencyContact = ""

    @State private var dateOfBirth: Date = Date()
    @State private var saveLabel: String = "Save Profile"

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(hex: "0A0F1E").ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        photoSection
                        formCard
                        healthNotesRow
                        saveButton
                        privacyNote
                        Spacer().frame(height: 40)
                    }
                    .padding(.top, 24)
                }
            }
        }
        .onAppear {
            if let saved = ISO8601DateFormatter().date(from: userDOB) {
                dateOfBirth = saved
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
            }

            Spacer()

            Text("Setup Profile")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)

            Spacer()

            Color.clear.frame(width: 36, height: 36)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Photo Section

    private var photoSection: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "111827"))
                        .frame(width: 100, height: 100)
                    Circle()
                        .stroke(Color(hex: "2563EB"), lineWidth: 2)
                        .frame(width: 100, height: 100)
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(hex: "2563EB"))
                }

                Button { print("photo picker — coming soon") } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "2563EB"))
                            .frame(width: 28, height: 28)
                        Image(systemName: "camera.fill.badge.plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .offset(x: 4, y: 4)
            }

            Text("Profile Photo")
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: "9CA3AF"))
        }
    }

    // MARK: - Form Card

    private var formCard: some View {
        VStack(spacing: 0) {
            // Full Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Full Name")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                TextField("John Doe", text: $userName)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(Color(hex: "2563EB"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "0A0F1E")))
            }
            .padding(16)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Date of Birth
            VStack(alignment: .leading, spacing: 8) {
                Text("Date of Birth")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                DatePicker(
                    "",
                    selection: $dateOfBirth,
                    displayedComponents: .date
                )
                .labelsHidden()
                .colorScheme(.dark)
                .tint(Color(hex: "2563EB"))
                .onChange(of: dateOfBirth) { _, newValue in
                    userDOB = ISO8601DateFormatter().string(from: newValue)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Emergency Contact
            VStack(alignment: .leading, spacing: 8) {
                Text("Emergency Contact")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                TextField("+1 (555) 000-0000", text: $emergencyContact)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .tint(Color(hex: "2563EB"))
                    .keyboardType(.phonePad)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(hex: "0A0F1E")))
            }
            .padding(16)
        }
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: "111827")))
        .padding(.horizontal, 20)
    }

    // MARK: - Health Notes Row

    private var healthNotesRow: some View {
        Button { print("health notes — coming soon") } label: {
            HStack {
                Text("Additional Health Notes")
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "6B7280"))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "111827"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                Color(hex: "374151"),
                                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            userDOB = ISO8601DateFormatter().string(from: dateOfBirth)
            saveLabel = "Saved!"
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: "2563EB"))
                HStack(spacing: 10) {
                    Text(saveLabel)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                    Image(systemName: saveLabel == "Saved!" ? "checkmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.2), value: saveLabel)
    }

    // MARK: - Privacy Note

    private var privacyNote: some View {
        Text("Your data is encrypted and stored locally. Only shared during emergency triggers.")
            .font(.system(size: 12))
            .foregroundStyle(Color(hex: "9CA3AF"))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
            .padding(.top, 12)
    }
}

#Preview {
    ProfileSetupView()
}
