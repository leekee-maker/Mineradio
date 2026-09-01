import SwiftUI

// MARK: - 日历伪装视图
struct CalendarDisguiseView: View {
    @State private var currentDate = Date()
    @State private var showingPasswordAlert = false
    @State private var passwordInput = ""
    @State private var titleTapCount = 0
    @State private var lastTitleTapTime: Date?

    private let calendar = Calendar.current
    private let weekdaySymbols = ["日", "一", "二", "三", "四", "五", "六"]

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: currentDate)
    }

    private var daysInMonth: [Date?] {
        generateDaysInMonth(for: currentDate)
    }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 星期标题行
                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(symbol == "日" || symbol == "六" ? .red : .secondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 8)

                // 日期网格
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
                    ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                        if let date = date {
                            DayCell(date: date, isToday: calendar.isDate(date, inSameDayAs: today))
                        } else {
                            Color.clear.frame(height: 44)
                        }
                    }
                }
                .padding(.horizontal, 8)

                // 假事件列表
                List {
                    Section {
                        FakeEventRow(time: "09:00", title: "项目周会", location: "会议室 A", color: .blue)
                        FakeEventRow(time: "14:30", title: "产品评审", location: "线上会议", color: .purple)
                        FakeEventRow(time: "18:00", title: "健身", location: "健身房", color: .green)
                    } header: {
                        Text("今天的事件")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button {
                        handleTitleTap()
                    } label: {
                        HStack(spacing: 6) {
                            Text(monthTitle)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        // 假装是添加事件
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        // 假装是月份切换
                        changeMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.red)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        changeMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .alert("输入指令", isPresented: $showingPasswordAlert) {
            TextField("请输入指令", text: $passwordInput)
                .keyboardType(.numberPad)
            Button("取消", role: .cancel) {
                passwordInput = ""
            }
            Button("确定") {
                verifyPassword()
            }
        } message: {
            Text("请输入访问指令")
        }
    }

    // MARK: - 标题点击处理（连续点击3次触发密码输入）
    private func handleTitleTap() {
        let now = Date()
        if let last = lastTitleTapTime, now.timeIntervalSince(last) < 1.5 {
            titleTapCount += 1
        } else {
            titleTapCount = 1
        }
        lastTitleTapTime = now

        if titleTapCount >= 3 {
            titleTapCount = 0
            showingPasswordAlert = true
        }
    }

    // MARK: - 密码验证
    private func verifyPassword() {
        let day = calendar.component(.day, from: Date())
        let expectedPassword = "\(day * 2)"

        if passwordInput.trimmingCharacters(in: .whitespacesAndNewlines) == expectedPassword {
            passwordInput = ""
            NotificationCenter.default.post(name: .enterMainApp, object: nil)
        } else {
            // 密码错误，清空
            passwordInput = ""
            // 再次弹出
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showingPasswordAlert = true
            }
        }
    }

    // MARK: - 月份切换
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentDate) {
            currentDate = newDate
        }
    }

    // MARK: - 生成月份日期
    private func generateDaysInMonth(for date: Date) -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [Date?] = []
        var current = monthFirstWeek.start

        while current < monthInterval.end {
            if calendar.isDate(current, equalTo: monthInterval.start, toGranularity: .month) {
                days.append(current)
            } else {
                days.append(nil)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        // 补齐到完整的行
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }
}

// MARK: - 日期单元格
private struct DayCell: View {
    let date: Date
    let isToday: Bool
    @State private var showingFakeEvent = false

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    var body: some View {
        Button {
            showingFakeEvent = true
        } label: {
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 16, weight: isToday ? .bold : .regular))
                    .foregroundStyle(isToday ? .white : (isWeekend ? .red : .primary))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isToday ? Color.red : Color.clear)
                    )
                // 假事件指示点
                if Int.random(in: 0...5) == 0 {
                    Circle()
                        .fill(Color.blue.opacity(0.6))
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear.frame(width: 4, height: 4)
                }
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .alert("事件详情", isPresented: $showingFakeEvent) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("当天暂无安排")
        }
    }
}

// MARK: - 假事件行
private struct FakeEventRow: View {
    let time: String
    let title: String
    let location: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                HStack(spacing: 4) {
                    Text(time)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(location)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 通知名称
extension Notification.Name {
    static let enterMainApp = Notification.Name("selfradio.enterMainApp")
}
