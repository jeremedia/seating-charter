# OpenAI BaseModel classes for structured data extraction
class OpenaiStudent < OpenAI::BaseModel
  required :name, String
  required :title, String, nil?: true
  required :organization, String, nil?: true
  required :location, String, nil?: true
  required :additional_info, String, nil?: true
  # Include inferred attributes with confidence scores in the same extraction
  required :gender, OpenAI::EnumOf[:male, :female, :unsure]  # Required enum with 3 options
  required :gender_confidence, Float  # 0.0 to 1.0, required
  required :agency_level, OpenAI::EnumOf[:federal, :state, :local, :private, :unsure]  # Required enum
  required :agency_level_confidence, Float
  required :department_type, OpenAI::EnumOf[:emergency_management, :fire, :police, :medical, :other, :unsure]  # Required enum
  required :department_type_confidence, Float
  required :seniority_level, OpenAI::EnumOf[:entry, :mid, :senior, :executive, :unsure]  # Required enum
  required :seniority_level_confidence, Float
end

class OpenaiStudentRoster < OpenAI::BaseModel
  required :students, OpenAI::ArrayOf[OpenaiStudent]
  required :total_count, Integer, nil?: true
  required :cohort_name, String, nil?: true
end

class OpenaiStudentAttribute < OpenAI::BaseModel
  required :confidence, Float # 0.0 to 1.0
  required :value, String
  required :reasoning, String, nil?: true
end

class OpenaiStudentAnalysis < OpenAI::BaseModel
  required :name, String
  required :gender, OpenaiStudentAttribute, nil?: true
  required :agency_level, OpenaiStudentAttribute, nil?: true
  required :department_type, OpenaiStudentAttribute, nil?: true
  required :seniority_level, OpenaiStudentAttribute, nil?: true
end