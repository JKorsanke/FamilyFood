import SwiftUI

struct MoveMealSheet: View {
    @Environment(\.dismiss) private var dismiss

    let sourceSlot: DaySlot
    let allSlots: [DaySlot]
    let onMove: (Weekday) -> Void

    private var targetSlots: [DaySlot] {
        allSlots.filter { $0.weekday != sourceSlot.weekday }
    }

    var body: some View {
        NavigationStack {
            List(targetSlots) { slot in
                Button {
                    onMove(slot.weekday)
                    dismiss()
                } label: {
                    HStack {
                        Text(slot.weekday.displayName)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(slotDescription(slot))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Verschieben nach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func slotDescription(_ slot: DaySlot) -> String {
        guard let meal = slot.meal else { return "Leer" }
        if meal.isExtern { return "Extern" }
        if meal.isAbendbrot { return "Abendbrot" }
        return meal.name
    }
}
