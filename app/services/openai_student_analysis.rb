# OpenAI BaseModel class for student analysis with attributes
class OpenaiStudentAnalysis < OpenAI::BaseModel
  required :name, String
  required :gender, OpenaiStudentAttribute, nil?: true
  required :agency_level, OpenaiStudentAttribute, nil?: true
  required :department_type, OpenaiStudentAttribute, nil?: true
  required :seniority_level, OpenaiStudentAttribute, nil?: true
end