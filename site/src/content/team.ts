export type TeamMember = {
  name: string;
  email: string;
  photo: string;
};

export const team: readonly TeamMember[] = [
  {
    name: "Christophe Domingos",
    email: "cdomingos@exadel.com",
    photo: "/assets/team/christophe.jpg",
  },
  {
    name: "Sandro Suladze",
    email: "ssuladze@exadel.com",
    photo: "/assets/team/sandro.jpg",
  },
  {
    name: "Eugene Burachevskiy",
    email: "eburachevskiy@exadel.com",
    photo: "/assets/team/eugene.jpg",
  },
];

export const collaboration: { paragraph: string } = {
  paragraph:
    "We worked as a single team across all three solutions — no per-product owners. We split daily into pair-and-rotate sessions, met morning and evening to compare notes, and kept one shared thesis pinned: AI is only as good as the structure you give it. Each solution is a different altitude on that idea. Anyone could (and did) commit to any of the three.",
};
