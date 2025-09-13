// 로컬 비공개 키 저장 (git에 올리지 않도록 주의). 현재 예시로 KAMIS 키/ID를 넣어둠.
// 공개 저장소라면 이 파일에 실제 키를 두지 말고 .gitignore 처리하거나 dart-define 사용.

class SecretService {
	// dart-define 미설정 시 fallback 으로 사용될 값
	// 필요시 빈 문자열로 바꾸고 launch.json / dart-define 로만 주입.
	static const String kamisCertKey = 'a25b3387-af9f-4e29-8b10-452b710a3a9a';
	static const String kamisCertId = '6257';
}
