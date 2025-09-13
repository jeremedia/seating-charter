# OpenAI BaseModel class for student attribute with confidence
class OpenaiStudentAttribute < OpenAI::BaseModel
  required :confidence, Float # 0.0 to 1.0
  required :value, String
  required :reasoning, String, nil?: true
end