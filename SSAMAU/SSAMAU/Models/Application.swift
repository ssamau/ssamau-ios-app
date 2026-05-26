import Foundation

/// One row from `applications.list`. Mirrors the membership_applications
/// schema + joined committee name. Used by HeadApplicationsView (own
/// committee queue) and AdminApplicationsView (everything).
struct Application: Codable, Identifiable, Equatable {
    let id: String                       // application_id
    let fullName: String?
    let preferredName: String?
    let nameAr: String?
    let nameEn: String?
    let email: String?
    let phone: String?
    let phoneCountryCode: String?
    let whatsapp: String?
    let whatsappCountryCode: String?
    let nationalId: String?
    let dateOfBirth: String?
    let gender: String?
    let addressMelbourne: String?
    let university: String?
    let universityOther: String?
    let studyLevel: String?
    let degreeField: String?
    let studyStartedWindow: String?
    let expectedGraduationWindow: String?
    let scholarshipEntity: String?
    let scholarshipEntityOther: String?
    let cvUrl: String?
    let skillsHobbies: String?
    let aboutSelf: String?
    let interests: [String]?             // committee ids the applicant ticked
    let pitch: String?
    let referralSource: String?
    let suggestions: String?
    let status: String?                  // PendingTriage / AssignedToCommittee / InterviewRequested / Accepted / Rejected
    let applicantType: String?           // 'Volunteer' / 'Member' / 'Head'
    let assignedCommitteeId: String?
    let assignedCommitteeName: String?
    let decisionReason: String?
    let createdAt: String?
    let decidedAt: String?
    let createdMemberId: String?

    var displayName: String {
        nameAr ?? fullName ?? preferredName ?? id
    }

    enum CodingKeys: String, CodingKey {
        case id   = "application_id"
        case fullName              = "full_name"
        case preferredName         = "preferred_name"
        case nameAr                = "name_ar"
        case nameEn                = "name_en"
        case email, phone, gender, university, status, interests, pitch, suggestions
        case phoneCountryCode      = "phone_country_code"
        case whatsapp, whatsappCountryCode = "whatsapp_country_code"
        case nationalId            = "national_id"
        case dateOfBirth           = "date_of_birth"
        case addressMelbourne      = "address_melbourne"
        case universityOther       = "university_other"
        case studyLevel            = "study_level"
        case degreeField           = "degree_field"
        case studyStartedWindow    = "study_started_window"
        case expectedGraduationWindow = "expected_graduation_window"
        case scholarshipEntity     = "scholarship_entity"
        case scholarshipEntityOther = "scholarship_entity_other"
        case cvUrl                 = "cv_url"
        case skillsHobbies         = "skills_hobbies"
        case aboutSelf             = "about_self"
        case referralSource        = "referral_source"
        case applicantType         = "applicant_type"
        case assignedCommitteeId   = "assigned_committee_id"
        case assignedCommitteeName = "assigned_committee_name"
        case decisionReason        = "decision_reason"
        case createdAt             = "created_at"
        case decidedAt             = "decided_at"
        case createdMemberId       = "created_member_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                  = try c.decode(String.self, forKey: .id)
        fullName            = try c.decodeIfPresent(String.self, forKey: .fullName)
        preferredName       = try c.decodeIfPresent(String.self, forKey: .preferredName)
        nameAr              = try c.decodeIfPresent(String.self, forKey: .nameAr)
        nameEn              = try c.decodeIfPresent(String.self, forKey: .nameEn)
        email               = try c.decodeIfPresent(String.self, forKey: .email)
        phone               = try c.decodeIfPresent(String.self, forKey: .phone)
        phoneCountryCode    = try c.decodeIfPresent(String.self, forKey: .phoneCountryCode)
        whatsapp            = try c.decodeIfPresent(String.self, forKey: .whatsapp)
        whatsappCountryCode = try c.decodeIfPresent(String.self, forKey: .whatsappCountryCode)
        nationalId          = try c.decodeIfPresent(String.self, forKey: .nationalId)
        dateOfBirth         = try c.decodeIfPresent(String.self, forKey: .dateOfBirth)
        gender              = try c.decodeIfPresent(String.self, forKey: .gender)
        addressMelbourne    = try c.decodeIfPresent(String.self, forKey: .addressMelbourne)
        university          = try c.decodeIfPresent(String.self, forKey: .university)
        universityOther     = try c.decodeIfPresent(String.self, forKey: .universityOther)
        studyLevel          = try c.decodeIfPresent(String.self, forKey: .studyLevel)
        degreeField         = try c.decodeIfPresent(String.self, forKey: .degreeField)
        studyStartedWindow  = try c.decodeIfPresent(String.self, forKey: .studyStartedWindow)
        expectedGraduationWindow = try c.decodeIfPresent(String.self, forKey: .expectedGraduationWindow)
        scholarshipEntity   = try c.decodeIfPresent(String.self, forKey: .scholarshipEntity)
        scholarshipEntityOther = try c.decodeIfPresent(String.self, forKey: .scholarshipEntityOther)
        cvUrl               = try c.decodeIfPresent(String.self, forKey: .cvUrl)
        skillsHobbies       = try c.decodeIfPresent(String.self, forKey: .skillsHobbies)
        aboutSelf           = try c.decodeIfPresent(String.self, forKey: .aboutSelf)
        // interests may serialize as array or null
        interests           = try c.decodeIfPresent([String].self, forKey: .interests)
        pitch               = try c.decodeIfPresent(String.self, forKey: .pitch)
        referralSource      = try c.decodeIfPresent(String.self, forKey: .referralSource)
        suggestions         = try c.decodeIfPresent(String.self, forKey: .suggestions)
        status              = try c.decodeIfPresent(String.self, forKey: .status)
        applicantType       = try c.decodeIfPresent(String.self, forKey: .applicantType)
        assignedCommitteeId = try c.decodeIfPresent(String.self, forKey: .assignedCommitteeId)
        assignedCommitteeName = try c.decodeIfPresent(String.self, forKey: .assignedCommitteeName)
        decisionReason      = try c.decodeIfPresent(String.self, forKey: .decisionReason)
        createdAt           = try c.decodeIfPresent(String.self, forKey: .createdAt)
        decidedAt           = try c.decodeIfPresent(String.self, forKey: .decidedAt)
        createdMemberId     = try c.decodeIfPresent(String.self, forKey: .createdMemberId)
    }
}
