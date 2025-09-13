# OpenAI BaseModel class for student roster collection
class OpenaiStudentRoster < OpenAI::BaseModel
  required :students, OpenAI::ArrayOf[OpenaiStudent]
  required :total_count, Integer, nil?: true
  required :cohort_name, String, nil?: true
end