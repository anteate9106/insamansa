-- =============================================
-- 성격유형검사 플랫폼 - Supabase 데이터베이스 스키마
-- =============================================

-- 기존 테이블이 있다면 삭제 (개발용)
DROP TABLE IF EXISTS result_answers CASCADE;
DROP TABLE IF EXISTS results CASCADE;
DROP TABLE IF EXISTS options CASCADE;
DROP TABLE IF EXISTS questions CASCADE;
DROP TABLE IF EXISTS tests CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;

-- Enum 타입 정의
DROP TYPE IF EXISTS test_slug CASCADE;
CREATE TYPE test_slug AS ENUM ('disc', 'mbti', 'stress');

-- =============================================
-- 1. 프로필 테이블 (사용자 정보)
-- =============================================
CREATE TABLE profiles (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    org TEXT, -- 소속
    name TEXT NOT NULL, -- 이름
    phone TEXT, -- 연락처
    email TEXT NOT NULL, -- 이메일
    user_type TEXT DEFAULT 'user' CHECK (user_type IN ('user', 'admin')), -- 사용자 유형
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- 2. 테스트 테이블
-- =============================================
CREATE TABLE tests (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    slug test_slug UNIQUE NOT NULL, -- 'disc', 'mbti', 'stress'
    name TEXT NOT NULL, -- 'DiSC 성격유형검사', 'MBTI 성격유형검사', '스트레스 관리 척도'
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- 3. 문제 테이블
-- =============================================
CREATE TABLE questions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    test_id UUID REFERENCES tests(id) ON DELETE CASCADE,
    question_text TEXT NOT NULL,
    question_order INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- 4. 선택지 테이블
-- =============================================
CREATE TABLE options (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    question_id UUID REFERENCES questions(id) ON DELETE CASCADE,
    option_text TEXT NOT NULL,
    option_order INTEGER NOT NULL,
    -- DiSC 점수 (해당되는 경우만 사용)
    disc_d_score INTEGER DEFAULT 0,
    disc_i_score INTEGER DEFAULT 0,
    disc_s_score INTEGER DEFAULT 0,
    disc_c_score INTEGER DEFAULT 0,
    -- MBTI 점수 (해당되는 경우만 사용)
    mbti_e_score INTEGER DEFAULT 0,
    mbti_i_score INTEGER DEFAULT 0,
    mbti_s_score INTEGER DEFAULT 0,
    mbti_n_score INTEGER DEFAULT 0,
    mbti_t_score INTEGER DEFAULT 0,
    mbti_f_score INTEGER DEFAULT 0,
    mbti_j_score INTEGER DEFAULT 0,
    mbti_p_score INTEGER DEFAULT 0,
    -- 스트레스 점수 (해당되는 경우만 사용)
    stress_score INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- 5. 결과 테이블
-- =============================================
CREATE TABLE results (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
    test_id UUID REFERENCES tests(id) ON DELETE CASCADE,
    completed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- DiSC 결과
    disc_d_score INTEGER DEFAULT 0,
    disc_i_score INTEGER DEFAULT 0,
    disc_s_score INTEGER DEFAULT 0,
    disc_c_score INTEGER DEFAULT 0,
    disc_result TEXT, -- 'D', 'I', 'S', 'C'
    -- MBTI 결과
    mbti_e_score INTEGER DEFAULT 0,
    mbti_i_score INTEGER DEFAULT 0,
    mbti_s_score INTEGER DEFAULT 0,
    mbti_n_score INTEGER DEFAULT 0,
    mbti_t_score INTEGER DEFAULT 0,
    mbti_f_score INTEGER DEFAULT 0,
    mbti_j_score INTEGER DEFAULT 0,
    mbti_p_score INTEGER DEFAULT 0,
    mbti_result TEXT, -- 'ENFP', 'ISTJ' 등
    -- 스트레스 결과
    stress_score INTEGER DEFAULT 0,
    stress_level TEXT, -- '낮음', '보통', '높음', '매우높음'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- 6. 답변 테이블 (개별 답변 기록)
-- =============================================
CREATE TABLE result_answers (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    result_id UUID REFERENCES results(id) ON DELETE CASCADE,
    question_id UUID REFERENCES questions(id) ON DELETE CASCADE,
    option_id UUID REFERENCES options(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================
-- 인덱스 생성
-- =============================================
CREATE INDEX idx_profiles_email ON profiles(email);
CREATE INDEX idx_questions_test_id ON questions(test_id);
CREATE INDEX idx_questions_order ON questions(question_order);
CREATE INDEX idx_options_question_id ON options(question_id);
CREATE INDEX idx_results_user_id ON results(user_id);
CREATE INDEX idx_results_test_id ON results(test_id);
CREATE INDEX idx_result_answers_result_id ON result_answers(result_id);

-- =============================================
-- RLS (Row Level Security) 활성화
-- =============================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE questions ENABLE ROW LEVEL SECURITY;
ALTER TABLE options ENABLE ROW LEVEL SECURITY;
ALTER TABLE results ENABLE ROW LEVEL SECURITY;
ALTER TABLE result_answers ENABLE ROW LEVEL SECURITY;

-- =============================================
-- RLS 정책 설정
-- =============================================

-- 프로필 정책
CREATE POLICY "사용자는 자신의 프로필만 조회/수정 가능" ON profiles
    FOR ALL USING (auth.uid() = id);

CREATE POLICY "관리자는 모든 프로필 조회 가능" ON profiles
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND user_type = 'admin'
        )
    );

-- 테스트 정책 (모든 사용자가 읽기 가능)
CREATE POLICY "모든 사용자가 테스트 조회 가능" ON tests
    FOR SELECT USING (true);

CREATE POLICY "관리자만 테스트 수정 가능" ON tests
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND user_type = 'admin'
        )
    );

-- 문제 정책
CREATE POLICY "모든 사용자가 문제 조회 가능" ON questions
    FOR SELECT USING (true);

CREATE POLICY "관리자만 문제 수정 가능" ON questions
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND user_type = 'admin'
        )
    );

-- 선택지 정책
CREATE POLICY "모든 사용자가 선택지 조회 가능" ON options
    FOR SELECT USING (true);

CREATE POLICY "관리자만 선택지 수정 가능" ON options
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND user_type = 'admin'
        )
    );

-- 결과 정책
CREATE POLICY "사용자는 자신의 결과만 조회 가능" ON results
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "사용자는 자신의 결과 생성 가능" ON results
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "관리자는 모든 결과 조회 가능" ON results
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND user_type = 'admin'
        )
    );

-- 답변 정책
CREATE POLICY "사용자는 자신의 답변만 조회 가능" ON result_answers
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM results 
            WHERE id = result_answers.result_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "사용자는 자신의 답변 생성 가능" ON result_answers
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM results 
            WHERE id = result_answers.result_id AND user_id = auth.uid()
        )
    );

CREATE POLICY "관리자는 모든 답변 조회 가능" ON result_answers
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles 
            WHERE id = auth.uid() AND user_type = 'admin'
        )
    );

-- =============================================
-- 함수 정의
-- =============================================

-- 새 사용자 가입 시 프로필 자동 생성
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, email, name)
    VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'name', '사용자'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 생성
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- 관리자 확인 함수
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM profiles 
        WHERE id = auth.uid() AND user_type = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 결과 저장 함수
CREATE OR REPLACE FUNCTION record_result(
    p_test_id UUID,
    p_answers JSONB
)
RETURNS UUID AS $$
DECLARE
    v_result_id UUID;
    v_user_id UUID;
    v_test_slug TEXT;
    v_disc_d INTEGER := 0;
    v_disc_i INTEGER := 0;
    v_disc_s INTEGER := 0;
    v_disc_c INTEGER := 0;
    v_mbti_e INTEGER := 0;
    v_mbti_i INTEGER := 0;
    v_mbti_s INTEGER := 0;
    v_mbti_n INTEGER := 0;
    v_mbti_t INTEGER := 0;
    v_mbti_f INTEGER := 0;
    v_mbti_j INTEGER := 0;
    v_mbti_p INTEGER := 0;
    v_stress_score INTEGER := 0;
    answer JSONB;
BEGIN
    v_user_id := auth.uid();
    
    -- 테스트 정보 가져오기
    SELECT slug INTO v_test_slug FROM tests WHERE id = p_test_id;
    
    -- 결과 레코드 생성
    INSERT INTO results (user_id, test_id)
    VALUES (v_user_id, p_test_id)
    RETURNING id INTO v_result_id;
    
    -- 각 답변 처리
    FOR answer IN SELECT * FROM jsonb_array_elements(p_answers)
    LOOP
        -- 답변 기록
        INSERT INTO result_answers (result_id, question_id, option_id)
        VALUES (
            v_result_id,
            (answer->>'question_id')::UUID,
            (answer->>'option_id')::UUID
        );
        
        -- 점수 누적 (선택지에서 점수 가져오기)
        IF v_test_slug = 'disc' THEN
            SELECT 
                v_disc_d + COALESCE(disc_d_score, 0),
                v_disc_i + COALESCE(disc_i_score, 0),
                v_disc_s + COALESCE(disc_s_score, 0),
                v_disc_c + COALESCE(disc_c_score, 0)
            INTO v_disc_d, v_disc_i, v_disc_s, v_disc_c
            FROM options WHERE id = (answer->>'option_id')::UUID;
        ELSIF v_test_slug = 'mbti' THEN
            SELECT 
                v_mbti_e + COALESCE(mbti_e_score, 0),
                v_mbti_i + COALESCE(mbti_i_score, 0),
                v_mbti_s + COALESCE(mbti_s_score, 0),
                v_mbti_n + COALESCE(mbti_n_score, 0),
                v_mbti_t + COALESCE(mbti_t_score, 0),
                v_mbti_f + COALESCE(mbti_f_score, 0),
                v_mbti_j + COALESCE(mbti_j_score, 0),
                v_mbti_p + COALESCE(mbti_p_score, 0)
            INTO v_mbti_e, v_mbti_i, v_mbti_s, v_mbti_n, v_mbti_t, v_mbti_f, v_mbti_j, v_mbti_p
            FROM options WHERE id = (answer->>'option_id')::UUID;
        ELSIF v_test_slug = 'stress' THEN
            SELECT v_stress_score + COALESCE(stress_score, 0)
            INTO v_stress_score
            FROM options WHERE id = (answer->>'option_id')::UUID;
        END IF;
    END LOOP;
    
    -- 최종 결과 업데이트
    UPDATE results SET
        disc_d_score = v_disc_d,
        disc_i_score = v_disc_i,
        disc_s_score = v_disc_s,
        disc_c_score = v_disc_c,
        mbti_e_score = v_mbti_e,
        mbti_i_score = v_mbti_i,
        mbti_s_score = v_mbti_s,
        mbti_n_score = v_mbti_n,
        mbti_t_score = v_mbti_t,
        mbti_f_score = v_mbti_f,
        mbti_j_score = v_mbti_j,
        mbti_p_score = v_mbti_p,
        stress_score = v_stress_score
    WHERE id = v_result_id;
    
    RETURN v_result_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- 기본 데이터 삽입
-- =============================================

-- 테스트 데이터
INSERT INTO tests (slug, name, description) VALUES
('disc', 'DiSC 성격유형검사', 'Dominance, Influence, Steadiness, Conscientiousness 성격유형 검사'),
('mbti', 'MBTI 성격유형검사', 'Myers-Briggs Type Indicator 성격유형 검사'),
('stress', '스트레스 관리 척도', '스트레스 수준 및 관리 능력 측정');

-- 관리자 계정 생성 (이메일을 실제 관리자 이메일로 변경하세요)
-- 실제 사용 시에는 Supabase Auth를 통해 관리자 계정을 생성하고
-- 아래 INSERT를 실행하거나 profiles 테이블에서 user_type을 'admin'으로 변경하세요

-- =============================================
-- 샘플 DiSC 문제 및 선택지
-- =============================================

-- DiSC 테스트 문제 1
INSERT INTO questions (test_id, question_text, question_order) 
SELECT id, '새로운 프로젝트를 시작할 때 나는...', 1 FROM tests WHERE slug = 'disc';

-- 선택지들
INSERT INTO options (question_id, option_text, option_order, disc_d_score, disc_i_score, disc_s_score, disc_c_score)
SELECT 
    q.id,
    unnest(ARRAY[
        '빠르게 시작하고 실행하면서 문제를 해결한다',
        '팀원들과 아이디어를 공유하며 즐겁게 진행한다',
        '신중하게 계획을 세우고 안정적으로 진행한다',
        '모든 세부사항을 검토하고 완벽하게 준비한다'
    ]),
    unnest(ARRAY[1, 2, 3, 4]),
    unnest(ARRAY[3, 1, 1, 1]),
    unnest(ARRAY[1, 3, 1, 1]),
    unnest(ARRAY[1, 1, 3, 1]),
    unnest(ARRAY[1, 1, 1, 3])
FROM questions q 
JOIN tests t ON q.test_id = t.id 
WHERE t.slug = 'disc' AND q.question_order = 1;

-- DiSC 테스트 문제 2
INSERT INTO questions (test_id, question_text, question_order) 
SELECT id, '동료와 의견이 다를 때 나는...', 2 FROM tests WHERE slug = 'disc';

INSERT INTO options (question_id, option_text, option_order, disc_d_score, disc_i_score, disc_s_score, disc_c_score)
SELECT 
    q.id,
    unnest(ARRAY[
        '직접적으로 의견을 표현하고 논쟁한다',
        '대화를 통해 설득하려고 노력한다',
        '상대방의 의견을 듣고 타협점을 찾는다',
        '사실과 데이터를 바탕으로 논리적으로 설명한다'
    ]),
    unnest(ARRAY[1, 2, 3, 4]),
    unnest(ARRAY[3, 1, 1, 1]),
    unnest(ARRAY[1, 3, 1, 1]),
    unnest(ARRAY[1, 1, 3, 1]),
    unnest(ARRAY[1, 1, 1, 3])
FROM questions q 
JOIN tests t ON q.test_id = t.id 
WHERE t.slug = 'disc' AND q.question_order = 2;

-- =============================================
-- 뷰 생성 (편의를 위한)
-- =============================================

-- 최근 결과 뷰
CREATE VIEW v_recent_results AS
SELECT 
    r.*,
    p.name as user_name,
    p.email as user_email,
    t.name as test_name,
    t.slug as test_slug
FROM results r
JOIN profiles p ON r.user_id = p.id
JOIN tests t ON r.test_id = t.id
ORDER BY r.completed_at DESC;

-- 대시보드 통계 뷰
CREATE VIEW v_dashboard_stats AS
SELECT 
    COUNT(DISTINCT r.user_id) as total_users,
    COUNT(r.id) as total_tests_taken,
    COUNT(CASE WHEN t.slug = 'disc' THEN r.id END) as disc_tests,
    COUNT(CASE WHEN t.slug = 'mbti' THEN r.id END) as mbti_tests,
    COUNT(CASE WHEN t.slug = 'stress' THEN r.id END) as stress_tests
FROM results r
JOIN tests t ON r.test_id = t.id;

-- 사용자별 결과 뷰
CREATE VIEW v_user_results AS
SELECT 
    r.*,
    p.name as user_name,
    p.email as user_email,
    t.name as test_name,
    t.slug as test_slug,
    ROW_NUMBER() OVER (PARTITION BY r.user_id, r.test_id ORDER BY r.completed_at DESC) as attempt_number
FROM results r
JOIN profiles p ON r.user_id = p.id
JOIN tests t ON r.test_id = t.id;

-- =============================================
-- 완료 메시지
-- =============================================
DO $$
BEGIN
    RAISE NOTICE '성격유형검사 플랫폼 데이터베이스 스키마가 성공적으로 생성되었습니다!';
    RAISE NOTICE '다음 단계:';
    RAISE NOTICE '1. Supabase Auth에서 관리자 계정을 생성하세요';
    RAISE NOTICE '2. profiles 테이블에서 해당 사용자의 user_type을 "admin"으로 변경하세요';
    RAISE NOTICE '3. 웹사이트의 Supabase 설정을 업데이트하세요';
END $$;
