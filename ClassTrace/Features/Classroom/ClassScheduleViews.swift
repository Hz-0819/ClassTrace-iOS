import SwiftUI

struct ClassEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppDependencies.self) private var dependencies
    let courses: [APICourse]
    let onSaved: () async -> Void

    @State private var name = ""
    @State private var courseId = ""
    @State private var classType = "SMALL_GROUP"
    @State private var billingMode = "PREPAID"
    @State private var scheduleMode = "weekly"
    @State private var weeklySlots = [WeeklySlot()]
    @State private var dateSlots = [DateSlot()]
    @State private var location = ""
    @State private var startDate = Date()
    @State private var price = 0.0
    @State private var totalHours = 20.0
    @State private var color = "#7BA3C0"
    @State private var isSaving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    formSection("基本信息", "class-blue") {
                        MPField(label: "班级名称", placeholder: "请输入班级名称", text: $name)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("关联课程").mpFormLabel()
                            Picker("关联课程", selection: $courseId) {
                                Text("不关联课程模板").tag("")
                                ForEach(courses) { Text($0.name).tag($0.id) }
                            }.pickerStyle(.menu).frame(maxWidth: .infinity, minHeight: 46, alignment: .leading).padding(.horizontal, 12).background(MPColor.page, in: RoundedRectangle(cornerRadius: 9))
                        }
                        MPChoiceRow(label: "班级类型", options: [("一对一", "ONE_ON_ONE"), ("小班课", "SMALL_GROUP")], selection: $classType)
                    }

                    formSection("上课时间", "timetable-blue") {
                        HStack(spacing: 10) {
                            scheduleModeButton("weekly", "固定周期", "按每周固定时间上课")
                            scheduleModeButton("flexible", "指定日期", "按具体日期逐次安排")
                        }
                        if scheduleMode == "weekly" { weeklyEditor } else { dateEditor }
                    }

                    formSection("上课信息", "info-green") {
                        MPField(label: "上课地点", placeholder: "请输入上课地点", text: $location)
                        DatePicker("开课日期", selection: $startDate, displayedComponents: .date).tint(MPColor.blue)
                    }

                    formSection("课费与课时", "wallet-brown") {
                        MPChoiceRow(label: "计费方式", options: [("预付课时", "PREPAID"), ("现金记账", "CASH")], selection: $billingMode)
                        MPNumberField(label: "单次课费（元）", value: $price)
                        if billingMode == "PREPAID" { MPNumberField(label: "预付总课时", value: $totalHours) }
                    }

                    if let error { Text(error).font(.footnote).foregroundStyle(MPColor.red).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 16) }
                }.padding(.vertical, 18)
            }
            .background(MPColor.page)
            .navigationTitle("创建班级")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button { Task { await save() } } label: {
                    HStack { if isSaving { ProgressView().tint(.white) }; Text("创建班级").font(.system(size: 17, weight: .semibold)) }
                        .foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 50).background(MPColor.blue, in: Capsule())
                }.buttonStyle(.plain).disabled(isSaving).padding(.horizontal, 20).padding(.vertical, 12).background(.white)
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } } }
        }
    }

    private var weeklyEditor: some View {
        VStack(spacing: 12) {
            ForEach($weeklySlots) { $slot in
                VStack(alignment: .leading, spacing: 12) {
                    Text("选择星期").mpFormLabel()
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 4), spacing: 8) {
                        ForEach(1...7, id: \.self) { day in
                            Button { if slot.weekdays.contains(day) { slot.weekdays.remove(day) } else { slot.weekdays.insert(day) } } label: {
                                Text(Self.weekdayNames[day - 1]).font(.system(size: 12, weight: .medium)).foregroundStyle(slot.weekdays.contains(day) ? .white : MPColor.text)
                                    .frame(maxWidth: .infinity, minHeight: 36).background(slot.weekdays.contains(day) ? MPColor.blue : .white, in: Capsule()).overlay(Capsule().stroke(Color.black.opacity(0.08)))
                            }.buttonStyle(.plain)
                        }
                    }
                    HStack { DatePicker("开始", selection: $slot.startTime, displayedComponents: .hourAndMinute); DatePicker("结束", selection: $slot.endTime, displayedComponents: .hourAndMinute) }.font(.system(size: 13))
                }.padding(14).background(MPColor.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            }
            addButton("添加另一组固定时间") { weeklySlots.append(WeeklySlot()) }
        }
    }

    private var dateEditor: some View {
        VStack(spacing: 12) {
            ForEach($dateSlots) { $slot in
                VStack(spacing: 10) {
                    DatePicker("上课日期", selection: $slot.date, displayedComponents: .date)
                    HStack { DatePicker("开始", selection: $slot.startTime, displayedComponents: .hourAndMinute); DatePicker("结束", selection: $slot.endTime, displayedComponents: .hourAndMinute) }.font(.system(size: 13))
                }.padding(14).background(MPColor.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
            }
            addButton("添加指定日期") { dateSlots.append(DateSlot()) }
        }
    }

    private func scheduleModeButton(_ value: String, _ title: String, _ detail: String) -> some View {
        Button { scheduleMode = value } label: {
            VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 14, weight: .bold)); Text(detail).font(.system(size: 10)).foregroundStyle(MPColor.secondary) }
                .foregroundStyle(scheduleMode == value ? MPColor.blue : MPColor.text).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).padding(.horizontal, 12)
                .background(scheduleMode == value ? MPColor.blue.opacity(0.12) : MPColor.page, in: RoundedRectangle(cornerRadius: 12)).overlay(RoundedRectangle(cornerRadius: 12).stroke(scheduleMode == value ? MPColor.blue : .clear))
        }.buttonStyle(.plain)
    }

    private func addButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: "plus").font(.system(size: 14, weight: .medium)).foregroundStyle(MPColor.blue).frame(maxWidth: .infinity, minHeight: 44).overlay(RoundedRectangle(cornerRadius: 10).stroke(MPColor.blue, style: StrokeStyle(lineWidth: 1, dash: [5]))) }.buttonStyle(.plain)
    }

    private func formSection<Content: View>(_ title: String, _ icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 11) {
            HStack { MPIconTile(image: icon, color: MPColor.blue, size: 32); Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(MPColor.text); Spacer() }.padding(.horizontal, 16)
            MPCard { VStack(alignment: .leading, spacing: 18) { content() } }.padding(.horizontal, 12)
        }
    }

    @MainActor private func save() async {
        error = nil
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { error = "请输入班级名称"; return }
        guard !location.trimmingCharacters(in: .whitespaces).isEmpty else { error = "请输入上课地点"; return }
        guard price > 0 else { error = "请输入有效的单次课费"; return }
        guard billingMode != "PREPAID" || totalHours > 0 else { error = "请输入有效的预付课时"; return }
        let validWeekly = weeklySlots.filter { !$0.weekdays.isEmpty && $0.endTime > $0.startTime }
        let validDates = dateSlots.filter { $0.endTime > $0.startTime }
        guard scheduleMode == "weekly" ? !validWeekly.isEmpty : !validDates.isEmpty else { error = "请至少添加一个有效的上课时间"; return }
        isSaving = true; defer { isSaving = false }
        do {
            let items = scheduleItems(validWeekly: validWeekly, validDates: validDates)
            let schedule = APIClassSchedule(mode: scheduleMode, text: items.map(scheduleLabel).joined(separator: "、"), days: items.compactMap(\.dayEn), items: items)
            let duration = items.first.map { minutes($0.startTime, $0.endTime) } ?? 60
            let repository = ClassTraceRepository(client: dependencies.client)
            let classroom = try await repository.createClass(name: name, type: classType, billingMode: billingMode, location: location, courseId: courseId.nilIfEmpty, schedule: schedule, price: price, totalHours: billingMode == "PREPAID" ? totalHours : 0, lessonDurationMinutes: duration, startDate: startDate, color: color)
            if scheduleMode == "weekly" {
                let end = Calendar.current.date(byAdding: .month, value: 6, to: startDate) ?? startDate
                for slot in validWeekly {
                    try await generate(repository, classroom.id, slot, end)
                }
            } else {
                for slot in validDates { try await create(repository, classroom.id, slot) }
            }
            await onSaved(); dismiss()
        } catch { self.error = error.localizedDescription }
    }

    private func scheduleItems(validWeekly: [WeeklySlot], validDates: [DateSlot]) -> [APIClassScheduleItem] {
        if scheduleMode == "weekly" {
            return validWeekly.flatMap { slot in slot.weekdays.sorted().map { day in APIClassScheduleItem(id: UUID().uuidString, day: Self.weekdayNames[day - 1], dayEn: Self.weekdayEnglish[day - 1], date: nil, startTime: time(slot.startTime), endTime: time(slot.endTime), time: "\(time(slot.startTime))-\(time(slot.endTime))") } }
        }
        return validDates.map { APIClassScheduleItem(id: UUID().uuidString, day: $0.date.formatted(.dateTime.weekday(.wide)), dayEn: nil, date: date($0.date), startTime: time($0.startTime), endTime: time($0.endTime), time: "\(time($0.startTime))-\(time($0.endTime))") }
    }
    private func scheduleLabel(_ item: APIClassScheduleItem) -> String { item.date.map { "\($0) \(item.startTime)-\(item.endTime)" } ?? "\(item.day ?? "") \(item.startTime)-\(item.endTime)" }
    private func generate(_ repository: ClassTraceRepository, _ id: String, _ slot: WeeklySlot, _ end: Date) async throws { _ = try await repository.generateSessions(classId: id, from: startDate, to: end, weekdays: slot.weekdays.sorted(), startTime: time(slot.startTime), durationMinutes: minutes(time(slot.startTime), time(slot.endTime))) }
    private func create(_ repository: ClassTraceRepository, _ id: String, _ slot: DateSlot) async throws { let calendar = Calendar.current; let hm = calendar.dateComponents([.hour,.minute], from: slot.startTime); let ehm = calendar.dateComponents([.hour,.minute], from: slot.endTime); let start = calendar.date(bySettingHour: hm.hour ?? 0, minute: hm.minute ?? 0, second: 0, of: slot.date) ?? slot.date; let end = calendar.date(bySettingHour: ehm.hour ?? 0, minute: ehm.minute ?? 0, second: 0, of: slot.date) ?? slot.date.addingTimeInterval(3600); _ = try await repository.createSession(classId: id, startsAt: start, endsAt: end) }
    private func time(_ value: Date) -> String { value.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)) }
    private func date(_ value: Date) -> String { let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"; return formatter.string(from: value) }
    private func minutes(_ start: String, _ end: String) -> Int { let s=start.split(separator:":").compactMap{Int($0)}, e=end.split(separator:":").compactMap{Int($0)}; guard s.count==2,e.count==2 else{return 60}; return max(15,(e[0]*60+e[1])-(s[0]*60+s[1])) }
    static let weekdayNames = ["周一","周二","周三","周四","周五","周六","周日"]
    static let weekdayEnglish = ["monday","tuesday","wednesday","thursday","friday","saturday","sunday"]
}

private struct WeeklySlot: Identifiable { let id = UUID(); var weekdays: Set<Int> = [1]; var startTime = Date(); var endTime = Date().addingTimeInterval(3600) }
private struct DateSlot: Identifiable { let id = UUID(); var date = Date(); var startTime = Date(); var endTime = Date().addingTimeInterval(3600) }

private struct MPField: View { let label: String; let placeholder: String; @Binding var text: String; var body: some View { VStack(alignment:.leading,spacing:8){ Text(label).mpFormLabel(); TextField(placeholder,text:$text).padding(.horizontal,12).frame(height:46).background(MPColor.page,in:RoundedRectangle(cornerRadius:9)) } } }
private struct MPNumberField: View { let label: String; @Binding var value: Double; var body: some View { VStack(alignment:.leading,spacing:8){ Text(label).mpFormLabel(); TextField("0",value:$value,format:.number).keyboardType(.decimalPad).padding(.horizontal,12).frame(height:46).background(MPColor.page,in:RoundedRectangle(cornerRadius:9)) } } }
private struct MPChoiceRow: View { let label: String; let options: [(String,String)]; @Binding var selection: String; var body: some View { VStack(alignment:.leading,spacing:8){ Text(label).mpFormLabel(); HStack(spacing:10){ ForEach(options.indices,id:\.self){ index in Button{selection=options[index].1}label:{Text(options[index].0).font(.system(size:14,weight:.medium)).foregroundStyle(selection==options[index].1 ? MPColor.blue:MPColor.text).frame(maxWidth:.infinity,minHeight:42).background(selection==options[index].1 ? MPColor.blue.opacity(0.12):MPColor.page,in:RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(selection==options[index].1 ? MPColor.blue:.clear))}.buttonStyle(.plain) } } } } }
private extension Text { func mpFormLabel() -> some View { font(.system(size:14,weight:.medium)).foregroundStyle(MPColor.text) } }

private struct LegacyScheduleCalendarView: View {
    @Environment(AppDependencies.self) private var dependencies
    @State private var mode = 0
    @State private var anchor = Date()
    @State private var sessions: [APISession] = []
    @State private var classes: [APIClassroom] = []
    @State private var showAdd = false
    @State private var error: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                HStack { Button { move(-1) } label: { Image(systemName:"chevron.left") }; Spacer(); Text(periodTitle).font(.system(size:18,weight:.bold)); Spacer(); Button { move(1) } label: { Image(systemName:"chevron.right") } }.foregroundStyle(MPColor.text).padding(.horizontal,20)
                Picker("日程范围",selection:$mode){Text("周视图").tag(0);Text("月视图").tag(1)}.pickerStyle(.segmented).padding(.horizontal,16).onChange(of:mode){_,_ in Task{await load()}}
                calendarStrip
                VStack(spacing: 14) {
                    if sessions.isEmpty { MPCard { MPEmptyView(image:"timetable",title:"这个时间段没有课程",detail:"可以新增单次课节，或在班级中设置固定周期排课") } }
                    ForEach(groupedDays,id:\.day){ group in VStack(spacing:9){ MPSectionHeader(title:group.day.formatted(.dateTime.month().day().weekday(.wide))); ForEach(group.sessions){ session in NavigationLink{SessionDetailView(sessionId:session.id)}label:{MPCard{HStack(spacing:12){MPIconTile(image:"time-blue",color:MPColor.blue,size:44);VStack(alignment:.leading,spacing:5){Text(session.classroom?.name ?? "课程").font(.system(size:15,weight:.semibold));Text("\(session.startsAt.formatted(date:.omitted,time:.shortened)) - \(session.endsAt.formatted(date:.omitted,time:.shortened))").font(.system(size:12)).foregroundStyle(MPColor.secondary)};Spacer();Text(session.status.localizedStatus).font(.caption).foregroundStyle(MPColor.blue)}}}.buttonStyle(.plain)} } }
                }.padding(.horizontal,16)
            }.padding(.vertical,16)
        }.background(MPColor.page).navigationTitle("我的课表").navigationBarTitleDisplayMode(.inline).toolbar{Button{showAdd=true}label:{Image(systemName:"plus")}}.sheet(isPresented:$showAdd){QuickSessionView(classes:classes){await load()}}.task{await load()}.refreshable{await load()}
    }
    private var range:(Date,Date){let c=Calendar.current;if mode==0{let interval=c.dateInterval(of:.weekOfYear,for:anchor)!;return(interval.start,interval.end)};let interval=c.dateInterval(of:.month,for:anchor)!;return(interval.start,interval.end)}
    private var periodTitle:String{mode==0 ? "\(range.0.formatted(.dateTime.month().day())) - \(range.1.addingTimeInterval(-1).formatted(.dateTime.month().day()))" : anchor.formatted(.dateTime.year().month(.wide))}
    private var days:[Date]{let count=mode==0 ? 7 : Calendar.current.range(of:.day,in:.month,for:anchor)?.count ?? 30;return(0..<count).compactMap{Calendar.current.date(byAdding:.day,value:$0,to:range.0)}}
    private var calendarStrip:some View{LazyVGrid(columns:Array(repeating:GridItem(.flexible(),spacing:4),count:7),spacing:8){ForEach(days,id:\.self){day in VStack(spacing:4){Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption).foregroundStyle(MPColor.secondary);Text(day.formatted(.dateTime.day())).font(.system(size:14,weight:.semibold)).foregroundStyle(Calendar.current.isDateInToday(day) ? .white:MPColor.text).frame(width:32,height:32).background(Calendar.current.isDateInToday(day) ? MPColor.blue:.clear,in:Circle());if sessions.contains(where:{Calendar.current.isDate($0.startsAt,inSameDayAs:day)}){Circle().fill(MPColor.coral).frame(width:5,height:5)}}}}.padding(12).background(.white,in:RoundedRectangle(cornerRadius:16)).padding(.horizontal,16)}
    private var groupedDays:[(day:Date,sessions:[APISession])]{days.compactMap{day in let values=sessions.filter{Calendar.current.isDate($0.startsAt,inSameDayAs:day)}.sorted{$0.startsAt<$1.startsAt};return values.isEmpty ? nil:(day,values)}}
    private func move(_ value:Int){anchor=Calendar.current.date(byAdding:mode==0 ? .weekOfYear:.month,value:value,to:anchor) ?? anchor;Task{await load()}}
    @MainActor private func load()async{do{let r=ClassTraceRepository(client:dependencies.client);async let s=r.sessions(from:range.0,to:range.1);async let c=r.classes();(sessions,classes)=try await(s,c);error=nil}catch{self.error=error.localizedDescription}}
}

private struct QuickSessionView: View {
    @Environment(\.dismiss)private var dismiss;@Environment(AppDependencies.self)private var dependencies;let classes:[APIClassroom];let onSaved:()async->Void
    @State private var classId="";@State private var startsAt=Date();@State private var duration=60;@State private var error:String?
    var body:some View{NavigationStack{Form{Picker("班级",selection:$classId){Text("请选择").tag("");ForEach(classes){Text($0.name).tag($0.id)}};DatePicker("上课日期与时间",selection:$startsAt);Stepper("时长：\(duration) 分钟",value:$duration,in:15...360,step:15);if let error{Text(error).foregroundStyle(MPColor.red)}}.navigationTitle("新增单次课节").toolbar{ToolbarItem(placement:.cancellationAction){Button("取消"){dismiss()}};ToolbarItem(placement:.confirmationAction){Button("保存"){Task{await save()}}.disabled(classId.isEmpty)}}}}
    @MainActor private func save()async{do{_=try await ClassTraceRepository(client:dependencies.client).createSession(classId:classId,startsAt:startsAt,endsAt:startsAt.addingTimeInterval(Double(duration*60)));await onSaved();dismiss()}catch{self.error=error.localizedDescription}}
}
