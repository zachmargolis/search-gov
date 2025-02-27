import React, { useState, ReactNode, createRef, useEffect, RefObject, useId } from 'react';
import { NavDropDownButton, Menu } from '@trussworks/react-uswds';

interface DropDownMenuProps {
  label: string,
  items: ReactNode[]
}

export const DropDownMenu = ({ label, items }: DropDownMenuProps) => {
  const id = useId();
  const [openMore, setOpenMore] = useState(false);
  const btnRef: RefObject<HTMLDivElement> = createRef();

  useEffect(() => {
    const closeDropDown = (event: Event) => {
      if (btnRef.current && !btnRef.current.contains(event.target as HTMLDivElement)) {
        setOpenMore(false);
      }
    };

    document.body.addEventListener('click', closeDropDown);

    return () => document.body.removeEventListener('click', closeDropDown);
  });

  return (
    <div ref={btnRef}>
      <NavDropDownButton
        menuId={id}
        onToggle={() => setOpenMore((prev) => !prev)}
        isOpen={openMore}
        label={label}
      />
      <Menu items={items} isOpen={openMore} id={id} />
    </div>
  );
};
